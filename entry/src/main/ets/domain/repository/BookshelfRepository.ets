import { Book } from '../model/Book';
import { ReadingRecord } from '../model/ReadingRecord';

export interface BookshelfRepository {
  listBooks(): Promise<Book[]>;
  addBook(book: Book): Promise<void>;
  listHistory(): Promise<ReadingRecord[]>;
  getReadingRecord(bookId: string): Promise<ReadingRecord | undefined>;
  saveReadingRecord(record: ReadingRecord): Promise<void>;
}
