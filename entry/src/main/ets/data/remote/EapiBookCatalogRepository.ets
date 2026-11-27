import { AppError } from '../../core/error/AppError';
import { isHttpsUrl } from '../../core/network/HttpClient';
import { HttpParameter } from '../../core/network/HttpTypes';
import { Book, BookFormat } from '../../domain/model/Book';
import { RemoteBookSource } from '../../domain/model/RemoteBookSource';
import { BookCatalogRepository } from '../../domain/repository/BookCatalogRepository';
import { EapiClient } from './EapiClient';
import { EapiAuthor, EapiBook, readBookText, readId, readText } from './EapiTypes';

export class EapiBookCatalogRepository implements BookCatalogRepository {
  private readonly api: EapiClient;
  constructor(api: EapiClient) { this.api = api; }

  async search(keyword: string): Promise<Book[]> {
    if (!keyword.trim()) throw new AppError('EMPTY_SEARCH', '请输入书名或作者。');
    const result = await this.api.post('/eapi/book/search', [new HttpParameter('message', keyword.trim()),
      new HttpParameter('page', '1'), new HttpParameter('limit', '20'),
      new HttpParameter('extensions[]', 'epub'), new HttpParameter('extensions[]', 'pdf')]);
    return this.mapBooks(result.books);
  }

  async getRecommended(): Promise<Book[]> {
    return this.mapBooks((await this.api.get('/eapi/user/book/recommended')).books);
  }

  async getPopular(): Promise<Book[]> {
    return this.mapBooks((await this.api.getPublic('/eapi/book/most-popular')).books);
  }

  private mapBooks(items: EapiBook[] | undefined): Book[] {
    if (!Array.isArray(items)) throw new AppError('INVALID_RESPONSE', '书源未返回有效的书籍列表。');
    const books: Book[] = [];
    const seen: Set<string> = new Set();
    items.forEach((item: EapiBook) => {
      if (!item || typeof item !== 'object') return;
      const id = readId(item.id), title = readBookText(item.title) || readBookText(item.name);
      const path = readText(item.href) || readText(item.url);
      const match = /\/book\/(\d+)\/([a-z0-9]+)(?:[/?#]|$)/i.exec(path);
      const hash = readText(item.hash) || (match && match[1] === id ? match[2] : '');
      const extension = readText(item.extension).toLowerCase();
      if (!id || !title || seen.has(id)) return;
      seen.add(id);
      let author = readBookText(item.author);
      if (!author && typeof item.authors === 'string') author = readBookText(item.authors);
      if (!author && Array.isArray(item.authors)) {
        author = item.authors.filter((value: EapiAuthor) => value !== null && typeof value === 'object')
          .map((value: EapiAuthor) => readBookText(value.name)).filter((value: string) => value.length > 0).join('、');
      }
      const format = extension === 'pdf' ? BookFormat.PDF : extension === 'epub' ? BookFormat.EPUB : BookFormat.Unknown;
      books.push(new Book(`remote:${id}:${hash}`, title, author, format,
        readBookText(item.description, true), '', false, '', 0.75, '#E8EEE7', undefined,
        new RemoteBookSource(this.api.http.baseUrl, id, hash, this.coverUrl(readText(item.cover)), extension.toUpperCase())));
    });
    if (items.length > 0 && books.length === 0) {
      throw new AppError('INVALID_RESPONSE', '书源返回了书目，但缺少有效的书名或编号，请稍后重试。');
    }
    return books;
  }

  private coverUrl(value: string): string {
    const url = value.startsWith('//') ? `https:${value}` : value.startsWith('/') ? `${this.api.http.baseUrl}${value}` : value;
    return isHttpsUrl(url) ? url : '';
  }
}
