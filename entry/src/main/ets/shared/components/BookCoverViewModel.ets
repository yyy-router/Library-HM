import { Book } from '../../domain/model/Book';
import { CoverImageRepository } from '../../domain/service/CoverImageRepository';

@Observed
export class BookCoverViewModel {
  image: string = '';
  private bookId: string = '';
  private url: string = '';
  private loadedUrl: string = '';
  private repository: CoverImageRepository | undefined = undefined;
  private version: number = 0;
  private pending: boolean = false;

  update(book: Book, repository: CoverImageRepository | undefined): void {
    const url = book.coverAsset ? '' : book.source?.coverUrl || '';
    const sameBook = this.bookId === book.id;
    const sameRequest = sameBook && this.url === url && this.repository === repository;
    if (sameRequest && (this.pending || (this.image && this.loadedUrl === url))) return;
    const version = ++this.version;
    this.bookId = book.id;
    this.url = url;
    this.repository = repository;
    this.pending = false;
    if (!sameBook || !url || !repository) {
      this.image = '';
      this.loadedUrl = '';
    }
    if (!url || !repository) return;
    const cached = repository.getCached(url);
    if (cached) {
      this.image = cached;
      this.loadedUrl = url;
      return;
    }
    // 同一本书更新元数据或封面地址时，保留已显示图片直到替换图像就绪。
    this.pending = true;
    repository.load(url).then((source: string) => {
      if (version !== this.version) return;
      this.image = source;
      this.loadedUrl = url;
    }).catch(() => {
      // 新封面失败时仍可保留同一本书的旧封面；切换书籍时不会保留旧图。
    }).finally(() => {
      if (version === this.version) this.pending = false;
    });
  }

  clearFailedImage(): void { this.image = ''; this.loadedUrl = ''; }

  close(): void {
    this.version++;
    this.bookId = '';
    this.url = '';
    this.pending = false;
    this.repository = undefined;
  }
}
