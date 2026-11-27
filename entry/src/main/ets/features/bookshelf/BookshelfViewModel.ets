import { Book } from '../../domain/model/Book';
import { ReadingRecord } from '../../domain/model/ReadingRecord';
import { BookshelfRepository } from '../../domain/repository/BookshelfRepository';
import { FileImporter } from '../../domain/service/FileImporter';
import { BookDownloader } from '../../domain/service/BookDownloader';
import { BookDownload, DownloadState, ShelfEntry, ShelfFilter, ShelfRow, ShelfSort } from '../../domain/model/ShelfEntry';
import { AppError } from '../../core/error/AppError';

@Observed
export class BookshelfViewModel {
  books: Book[] = [];
  history: ReadingRecord[] = [];
  busy: boolean = false;
  message: string = '';
  query: string = '';
  filter: ShelfFilter = ShelfFilter.All;
  sort: ShelfSort = ShelfSort.Recent;
  entries: ShelfEntry[] = [];
  readingCount: number = 0;
  lastReadBookId: string = '';
  private readonly repository: BookshelfRepository;
  private readonly importer: FileImporter;
  private readonly downloader: BookDownloader;
  private readonly downloads: Map<string, BookDownload> = new Map<string, BookDownload>();

  constructor(repository: BookshelfRepository, importer: FileImporter, downloader: BookDownloader) {
    this.repository = repository;
    this.importer = importer;
    this.downloader = downloader;
  }

  async load(): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    try {
      this.books = await this.repository.listBooks();
      this.history = await this.repository.listHistory();
      this.applyFilters();
    } catch {
      this.message = '书架加载失败。';
    } finally {
      this.busy = false;
    }
  }

  async importBook(): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    this.message = '';
    try {
      const book = await this.importer.importBook();
      if (book) {
        await this.repository.addBook(book);
        this.books = await this.repository.listBooks();
        this.filter = ShelfFilter.All;
        this.query = '';
        this.applyFilters();
        this.message = book.hasLocalFile() ? '本地图书已导入。' :
          '已添加演示书目，真实文件导入尚未接入，当前没有可阅读的本地文件。';
      }
    } catch (error) {
      this.message = error instanceof AppError ? error.message : '导入失败，请稍后重试。';
    } finally {
      this.busy = false;
    }
  }

  setFilter(filter: ShelfFilter): void {
    this.filter = filter;
    this.applyFilters();
  }

  async downloadBook(book: Book): Promise<void> {
    const current = this.books.find((item: Book) => item.id === book.id);
    if (!current || this.busy || current.hasLocalFile() ||
      this.downloads.get(book.id)?.state === DownloadState.Downloading) return;
    this.message = '';
    this.downloads.set(book.id, new BookDownload(DownloadState.Downloading));
    this.applyFilters();
    try {
      const file = await this.downloader.download(current, (progress: number) => {
        if (!Number.isFinite(progress) ||
          this.downloads.get(book.id)?.state !== DownloadState.Downloading) return;
        this.downloads.set(book.id, new BookDownload(DownloadState.Downloading,
          Math.max(0, Math.min(1, progress))));
        this.applyFilters();
      });
      const saved = await this.repository.saveLocalFile(book.id, file);
      this.books = this.books.map((item: Book) => item.id === book.id ? saved : item);
      this.downloads.delete(book.id);
      this.message = '下载完成，文件已保存到本地。';
    } catch (error) {
      this.downloads.set(book.id, new BookDownload(DownloadState.Failed));
      this.message = error instanceof AppError && error.code === 'NOT_IMPLEMENTED' ? error.message :
        '下载失败，收藏与阅读记录已保留，请重试。';
    } finally {
      this.applyFilters();
    }
  }

  setQuery(query: string): void {
    this.query = query;
    this.applyFilters();
  }

  setSort(sort: ShelfSort): void {
    this.sort = sort;
    this.applyFilters();
  }

  rows(columns: number): ShelfRow[] {
    const rows: ShelfRow[] = [];
    const count = Math.max(1, Math.floor(columns));
    for (let index = 0; index < this.entries.length; index += count) {
      rows.push(new ShelfRow(this.entries.slice(index, index + count)));
    }
    return rows;
  }

  private applyFilters(): void {
    const all = this.books.map((book: Book) => {
      const record = this.history.find((item: ReadingRecord) => item.book.id === book.id);
      return new ShelfEntry(book, record ? record.progress : 0, record ? record.updatedAt : 0,
        this.downloads.get(book.id));
    });
    this.readingCount = all.filter((entry: ShelfEntry) => entry.progress > 0 && entry.progress < 1).length;
    const recent = all.filter((entry: ShelfEntry) => entry.updatedAt > 0)
      .sort((left: ShelfEntry, right: ShelfEntry) => right.updatedAt - left.updatedAt);
    this.lastReadBookId = recent.length > 0 ? recent[0].book.id : '';
    const query = this.query.trim().toLowerCase();
    this.entries = all.filter((entry: ShelfEntry) => {
      const matches = `${entry.book.title} ${entry.book.author}`.toLowerCase().includes(query);
      return matches && (this.filter === ShelfFilter.All ||
        (this.filter === ShelfFilter.Reading && entry.progress > 0 && entry.progress < 1) ||
        (this.filter === ShelfFilter.Finished && entry.progress === 1));
    }).sort((left: ShelfEntry, right: ShelfEntry) => {
      if (this.sort === ShelfSort.Title) return left.book.title.localeCompare(right.book.title, 'zh-CN');
      if (this.sort === ShelfSort.Progress) return right.progress - left.progress;
      return right.updatedAt - left.updatedAt;
    });
  }
}
