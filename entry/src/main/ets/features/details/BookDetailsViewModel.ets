import { AppError } from '../../core/error/AppError';
import { Book, BookFormat } from '../../domain/model/Book';
import { BookDetails } from '../../domain/model/BookDetails';
import { BookCatalogRepository } from '../../domain/repository/BookCatalogRepository';
import { BookshelfRepository } from '../../domain/repository/BookshelfRepository';

interface CachedDetails { details: BookDetails; expiresAt: number; }

@Observed
export class BookDetailsViewModel {
  book: Book = new Book('', '', '', BookFormat.Unknown, '');
  details: BookDetails | undefined = undefined;
  loading: boolean = false;
  message: string = '';
  requiresLogin: boolean = false;
  saved: boolean = false;
  shelfReady: boolean = false;
  shelfLoading: boolean = false;
  saving: boolean = false;
  shelfMessage: string = '';
  private version: number = 0;
  private readonly catalog: BookCatalogRepository;
  private readonly bookshelf: BookshelfRepository;
  private readonly cache: Map<string, CachedDetails> = new Map<string, CachedDetails>();
  private readonly now: () => number;

  constructor(catalog: BookCatalogRepository, bookshelf: BookshelfRepository, now: () => number = () => Date.now()) {
    this.catalog = catalog;
    this.bookshelf = bookshelf;
    this.now = now;
  }

  get hasLoadError(): boolean {
    return !this.loading && this.details === undefined && this.message.length > 0;
  }

  async open(book: Book): Promise<void> {
    this.version++;
    const cached = this.cachedDetails(book);
    this.book = cached ? cached.book : book;
    this.details = cached;
    this.loading = false;
    this.message = '';
    this.requiresLogin = false;
    this.saved = false;
    this.shelfReady = false;
    this.shelfLoading = false;
    this.saving = false;
    this.shelfMessage = '';
    await Promise.all([cached ? Promise.resolve() : this.loadDetails(), this.refreshShelf()]);
  }

  close(): void {
    this.version++;
    this.loading = false;
    this.shelfLoading = false;
    this.saving = false;
  }

  async loadDetails(): Promise<void> {
    if (this.loading || !this.book.id) return;
    const version = this.version;
    const book = this.book;
    this.loading = true;
    this.message = '';
    this.requiresLogin = false;
    try {
      const details = await this.catalog.getDetails(book);
      if (version !== this.version) return;
      this.details = details;
      this.book = details.book;
      const key = this.cacheKey(book);
      if (key) {
        this.cache.delete(key);
        this.cache.set(key, { details: details, expiresAt: this.now() + 5 * 60 * 1000 });
        while (this.cache.size > 12) this.cache.delete(this.cache.keys().next().value as string);
      }
    } catch (error) {
      if (version !== this.version) return;
      this.requiresLogin = error instanceof AppError && error.code === 'AUTH_REQUIRED';
      this.message = error instanceof AppError ? error.message : '暂时无法获取书籍详情，请稍后重试。';
    } finally {
      if (version === this.version) this.loading = false;
    }
  }

  private cacheKey(book: Book): string {
    const source = book.source;
    return source?.origin && source.id && source.hash ? JSON.stringify([source.origin, source.id, source.hash]) : '';
  }

  private cachedDetails(book: Book): BookDetails | undefined {
    const key = this.cacheKey(book);
    const cached = this.cache.get(key);
    if (!cached) return undefined;
    if (cached.expiresAt <= this.now()) { this.cache.delete(key); return undefined; }
    this.cache.delete(key); this.cache.set(key, cached);
    const details = cached.details;
    const value = details.book;
    // 只复用公开详情；本地文件状态始终采用本次所选书籍的数据。
    const merged = new Book(book.id, value.title, value.author, value.format, value.description,
      book.localUri, book.isDemo, book.coverAsset, book.coverAspectRatio, book.coverBackground, book.localFile, value.source);
    return new BookDetails(merged, details.publisher, details.year, details.language, details.pages,
      details.edition, details.identifier, details.fileSize);
  }

  async refreshShelf(): Promise<void> {
    if (this.shelfLoading || this.saving || !this.book.id) return;
    const version = this.version;
    const bookId = this.book.id;
    this.shelfLoading = true;
    this.shelfMessage = '';
    try {
      const books = await this.bookshelf.listBooks();
      if (version !== this.version) return;
      this.saved = books.some((item: Book) => item.id === bookId);
      this.shelfReady = true;
    } catch {
      if (version !== this.version) return;
      this.shelfReady = false;
      this.shelfMessage = '暂时无法读取收藏状态，请重试。';
    } finally {
      if (version === this.version) this.shelfLoading = false;
    }
  }

  async save(): Promise<void> {
    if (this.saving || this.saved || !this.shelfReady || this.shelfLoading) return;
    const version = this.version;
    const book = this.book;
    this.saving = true;
    this.shelfMessage = '';
    try {
      await this.bookshelf.addBook(book.asBookmark());
      if (version !== this.version) return;
      this.saved = true;
      this.shelfMessage = '已收藏到书架，下载后即可阅读。';
    } catch {
      if (version === this.version) this.shelfMessage = '收藏失败，请重试。';
    } finally {
      if (version === this.version) this.saving = false;
    }
  }
}
