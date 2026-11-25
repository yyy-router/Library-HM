import { AppError } from '../../core/error/AppError';
import { AccountSession } from '../../domain/model/AccountSession';
import { Book, BookFormat } from '../../domain/model/Book';
import { ReadingRecord } from '../../domain/model/ReadingRecord';
import { AccountRepository } from '../../domain/repository/AccountRepository';
import { BookCatalogRepository } from '../../domain/repository/BookCatalogRepository';
import { BookshelfRepository } from '../../domain/repository/BookshelfRepository';

function createDemoBooks(): Book[] {
  return [
    new Book('demo-epub', '阅读示例 · EPUB', '演示书籍', BookFormat.EPUB,
      '用于演示书籍搜索、加入书架和阅读页面，不包含真实文件。'),
    new Book('demo-pdf', '阅读示例 · PDF', '演示书籍', BookFormat.PDF,
      '用于演示 PDF 书籍条目，阅读引擎将在后续接入。'),
    new Book('demo-guide', '平板阅读指南', '演示书籍', BookFormat.EPUB,
      '首页搜索和书架展示使用的临时数据。')
  ];
}

export class DemoBookCatalogRepository implements BookCatalogRepository {
  private readonly books: Book[] = createDemoBooks();

  async search(keyword: string): Promise<Book[]> {
    const query = keyword.trim().toLowerCase();
    return this.books.filter((book: Book) =>
      `${book.title} ${book.author} ${book.format}`.toLowerCase().includes(query));
  }
}

export class DemoBookshelfRepository implements BookshelfRepository {
  private books: Book[] = createDemoBooks().slice(0, 2);
  private readonly history: Map<string, ReadingRecord> = new Map<string, ReadingRecord>();

  async listBooks(): Promise<Book[]> {
    return this.books.slice();
  }

  async addBook(book: Book): Promise<void> {
    if (!this.books.some((item: Book) => item.id === book.id)) {
      this.books = [book, ...this.books];
    }
  }

  async listHistory(): Promise<ReadingRecord[]> {
    return Array.from(this.history.values()).sort((left: ReadingRecord, right: ReadingRecord) =>
      right.updatedAt - left.updatedAt);
  }

  async getReadingRecord(bookId: string): Promise<ReadingRecord | undefined> {
    return this.history.get(bookId);
  }

  async saveReadingRecord(record: ReadingRecord): Promise<void> {
    this.history.set(record.book.id, record);
  }
}

export class DemoAccountRepository implements AccountRepository {
  async getSession(): Promise<AccountSession | undefined> {
    return undefined;
  }

  async signIn(_email: string, _password: string): Promise<AccountSession> {
    throw new AppError('NOT_IMPLEMENTED', '登录服务尚未接入，当前可直接使用演示搜索。');
  }

  async signOut(): Promise<void> {
    // TODO: 替换为真实账户仓库后，在此清理安全存储中的会话。
  }
}
