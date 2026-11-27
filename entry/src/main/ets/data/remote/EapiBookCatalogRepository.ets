import { AppError } from '../../core/error/AppError';
import { isHttpsUrl } from '../../core/network/HttpClient';
import { HttpParameter } from '../../core/network/HttpTypes';
import { Book, BookFormat } from '../../domain/model/Book';
import { BookDetails } from '../../domain/model/BookDetails';
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

  async getDetails(book: Book): Promise<BookDetails> {
    const item = (await this.api.getBookDetails(book)).book;
    const source = book.source;
    if (!source || !item || typeof item !== 'object' || Array.isArray(item) ||
      !readBookText(item.title) || (item.id !== undefined && readId(item.id) !== source.id) ||
      (readText(item.hash) && readText(item.hash) !== source.hash)) {
      throw new AppError('INVALID_RESPONSE', '书源未返回与当前书籍匹配的详情。');
    }
    const extension = readText(item.extension).toLowerCase() || source.extension.toLowerCase();
    const format = extension === 'pdf' ? BookFormat.PDF : extension === 'epub' ? BookFormat.EPUB : BookFormat.Unknown;
    const detailedBook = new Book(book.id, readBookText(item.title), this.author(item) || book.author,
      format, readBookText(item.description, true) || book.description, book.localUri, book.isDemo,
      book.coverAsset, book.coverAspectRatio, book.coverBackground, book.localFile,
      new RemoteBookSource(source.origin, source.id, source.hash,
        this.coverUrl(readText(item.cover)) || source.coverUrl, extension.toUpperCase()));
    return new BookDetails(detailedBook, readBookText(item.publisher), this.scalar(item.year),
      readBookText(item.language), this.scalar(item.pages), this.scalar(item.edition),
      this.scalar(item.identifier) || this.scalar(item.isbn), this.fileSize(item));
  }

  private scalar(value: string | number | undefined): string {
    if (typeof value === 'number') return Number.isFinite(value) && value > 0 ? String(value) : '';
    return readBookText(value);
  }

  private fileSize(item: EapiBook): string {
    const label = readBookText(item.filesizeString);
    if (label) return label;
    const bytes = Number(item.filesize);
    if (!Number.isFinite(bytes) || bytes <= 0) return '';
    if (bytes < 1024) return `${Math.round(bytes)} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }

  private author(item: EapiBook): string {
    const author = readBookText(item.author);
    if (author) return author;
    if (typeof item.authors === 'string') return readBookText(item.authors);
    if (!Array.isArray(item.authors)) return '';
    return item.authors.filter((value: EapiAuthor) => value !== null && typeof value === 'object')
      .map((value: EapiAuthor) => readBookText(value.name)).filter((value: string) => value.length > 0).join('、');
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
      const author = this.author(item);
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
