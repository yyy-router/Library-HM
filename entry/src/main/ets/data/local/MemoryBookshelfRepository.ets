import { AppError } from '../../core/error/AppError';
import { Book } from '../../domain/model/Book';
import { LocalBookFile } from '../../domain/model/LocalBookFile';
import { ReadingRecord } from '../../domain/model/ReadingRecord';
import { BookshelfRepository } from '../../domain/repository/BookshelfRepository';

export class MemoryBookshelfRepository implements BookshelfRepository {
  private books: Book[];
  private readonly history: Map<string, ReadingRecord> = new Map<string, ReadingRecord>();

  constructor(books: Book[] = [], history: ReadingRecord[] = []) {
    this.books = books.slice();
    history.forEach((record: ReadingRecord) => this.history.set(record.book.id, record));
  }
  async listBooks(): Promise<Book[]> { return this.books.slice(); }
  async addBook(book: Book): Promise<void> {
    if (!this.books.some((item: Book) => item.id === book.id)) this.books = [book, ...this.books];
  }
  async listHistory(): Promise<ReadingRecord[]> {
    return Array.from(this.history.values()).sort((a: ReadingRecord, b: ReadingRecord) => b.updatedAt - a.updatedAt);
  }
  async saveLocalFile(bookId: string, file: LocalBookFile): Promise<Book> {
    const book = this.books.find((item: Book) => item.id === bookId);
    if (!book || !file.isValid()) throw new AppError('INVALID_LOCAL_FILE', '书籍不存在或下载未生成有效本地文件。');
    const saved = book.withLocalFile(file);
    this.books = this.books.map((item: Book) => item.id === bookId ? saved : item);
    return saved;
  }
  async getReadingRecord(bookId: string): Promise<ReadingRecord | undefined> { return this.history.get(bookId); }
  async saveReadingRecord(record: ReadingRecord): Promise<void> { this.history.set(record.book.id, record); }
}
