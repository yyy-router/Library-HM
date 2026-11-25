import { Book } from './Book';

export enum ShelfFilter { All, Reading, Finished }
export enum ShelfSort { Recent, Title, Progress }

export class ShelfEntry {
  readonly book: Book;
  readonly progress: number;
  readonly updatedAt: number;

  constructor(book: Book, progress: number = 0, updatedAt: number = 0) {
    this.book = book;
    this.progress = progress;
    this.updatedAt = updatedAt;
  }
}

export class ShelfRow {
  readonly id: string;
  readonly entries: ShelfEntry[];

  constructor(entries: ShelfEntry[]) {
    this.entries = entries;
    this.id = entries.map((entry: ShelfEntry) =>
      `${entry.book.id}:${entry.progress}:${entry.updatedAt}`).join('|');
  }
}
