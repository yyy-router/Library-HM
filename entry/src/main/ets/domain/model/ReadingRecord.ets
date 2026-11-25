import { Book } from './Book';

export class ReadingRecord {
  readonly book: Book;
  readonly progress: number;
  readonly locator: string;
  readonly updatedAt: number;

  constructor(book: Book, progress: number, locator: string, updatedAt: number) {
    this.book = book;
    this.progress = Math.max(0, Math.min(1, progress));
    this.locator = locator;
    this.updatedAt = updatedAt;
  }
}
