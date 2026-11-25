import { Book } from '../../domain/model/Book';
import { ReadingRecord } from '../../domain/model/ReadingRecord';
import { BookshelfRepository } from '../../domain/repository/BookshelfRepository';
import { FileImporter } from '../../domain/service/FileImporter';
import { ShelfEntry, ShelfFilter, ShelfRow, ShelfSort } from '../../domain/model/ShelfEntry';

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

  constructor(repository: BookshelfRepository, importer: FileImporter) {
    this.repository = repository;
    this.importer = importer;
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
        this.message = '已添加演示书籍，真实文件选择与解析尚未接入。';
      }
    } catch {
      this.message = '导入失败，请稍后重试。';
    } finally {
      this.busy = false;
    }
  }

  setFilter(filter: ShelfFilter): void {
    this.filter = filter;
    this.applyFilters();
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
      return new ShelfEntry(book, record ? record.progress : 0, record ? record.updatedAt : 0);
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
