import { AppError } from '../../core/error/AppError';
import { AccountSession } from '../../domain/model/AccountSession';
import { Book } from '../../domain/model/Book';
import { LocalBookFile } from '../../domain/model/LocalBookFile';
import { ReadingRecord } from '../../domain/model/ReadingRecord';
import { AccountRepository } from '../../domain/repository/AccountRepository';
import { BookCatalogRepository } from '../../domain/repository/BookCatalogRepository';
import { BookshelfRepository } from '../../domain/repository/BookshelfRepository';
import { createDemoBooks } from './DemoBooks';

export class DemoBookCatalogRepository implements BookCatalogRepository {
  private readonly books: Book[] = createDemoBooks();

  async search(keyword: string): Promise<Book[]> {
    const query = keyword.trim().toLowerCase();
    return this.books.filter((book: Book) =>
      `${book.title} ${book.author} ${book.format}`.toLowerCase().includes(query));
  }

  async getRecommended(): Promise<Book[]> {
    throw new AppError('NOT_IMPLEMENTED', '推荐服务尚未接入。');
  }
}

export class DemoBookshelfRepository implements BookshelfRepository {
  private books: Book[] = createDemoBooks().slice(0, 8);
  private readonly history: Map<string, ReadingRecord> = new Map<string, ReadingRecord>();

  constructor(withSampleHistory: boolean = true) {
    if (withSampleHistory) {
      const progress: number[] = [0.43, 0.68, 0.16, 0, 1, 0, 0.27, 0];
      const now = Date.now();
      this.books.forEach((book: Book, index: number) => {
        if (progress[index] > 0) {
          this.history.set(book.id, new ReadingRecord(book, progress[index],
            `demo:${Math.round(progress[index] * 100)}`, now - (index + 1) * 60000));
        }
      });
    }
  }

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

  async saveLocalFile(bookId: string, file: LocalBookFile): Promise<Book> {
    const index = this.books.findIndex((book: Book) => book.id === bookId);
    if (index < 0 || !file.isValid()) {
      throw new AppError('INVALID_LOCAL_FILE', '书籍不存在或下载未生成有效本地文件。');
    }
    const book = this.books[index].withLocalFile(file);
    this.books = this.books.map((item: Book) => item.id === bookId ? book : item);
    return book;
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
