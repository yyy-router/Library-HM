import { Book } from '../model/Book';
import { ReadingRecord } from '../model/ReadingRecord';
import { LocalBookFile } from '../model/LocalBookFile';

export interface BookshelfRepository {
  listBooks(): Promise<Book[]>;
  addBook(book: Book): Promise<void>;
  saveLocalFile(bookId: string, file: LocalBookFile): Promise<Book>;
  listHistory(): Promise<ReadingRecord[]>;
  getReadingRecord(bookId: string): Promise<ReadingRecord | undefined>;
  saveReadingRecord(record: ReadingRecord): Promise<void>;
}
