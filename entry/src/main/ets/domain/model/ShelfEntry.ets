import { Book } from './Book';

export enum ShelfFilter { All, Reading, Finished }
export enum ShelfSort { Recent, Title, Progress }
export enum DownloadState { NotDownloaded, Downloading, Downloaded, Failed }

export class BookDownload {
  readonly state: DownloadState;
  readonly progress: number;

  constructor(state: DownloadState, progress: number = 0) {
    this.state = state;
    this.progress = progress;
  }
}

export class ShelfEntry {
  readonly book: Book;
  readonly progress: number;
  readonly updatedAt: number;
  readonly download: BookDownload;

  constructor(book: Book, progress: number = 0, updatedAt: number = 0,
    download: BookDownload = new BookDownload(DownloadState.NotDownloaded)) {
    this.book = book;
    this.progress = progress;
    this.updatedAt = updatedAt;
    this.download = book.hasLocalFile() ? new BookDownload(DownloadState.Downloaded, 1) : download;
  }
}

export class ShelfRow {
  readonly id: string;
  readonly entries: ShelfEntry[];

  constructor(entries: ShelfEntry[]) {
    this.entries = entries;
    this.id = entries.map((entry: ShelfEntry) =>
      `${entry.book.id}:${entry.progress}:${entry.updatedAt}:${entry.download.state}:${entry.download.progress}`).join('|');
  }
}
