import { Book, BookFormat } from '../../domain/model/Book';
import { ReadingRecord } from '../../domain/model/ReadingRecord';
import { BookshelfRepository } from '../../domain/repository/BookshelfRepository';

@Observed
export class ReaderViewModel {
  book: Book = new Book('placeholder', '阅读器', '', BookFormat.EPUB, '');
  progress: number = 0;
  busy: boolean = false;
  message: string = '';
  private readonly repository: BookshelfRepository;

  constructor(repository: BookshelfRepository) {
    this.repository = repository;
  }

  async open(book: Book): Promise<boolean> {
    this.book = book;
    this.progress = 0;
    this.message = '';
    if (!book.hasLocalFile()) {
      this.message = '这本书尚无本地文件，请先在书架下载，或导入本地文件。';
      return false;
    }
    this.busy = true;
    try {
      const record = await this.repository.getReadingRecord(book.id);
      this.progress = record ? record.progress : 0;
    } catch {
      this.message = '读取演示进度失败。';
    } finally {
      this.busy = false;
    }
    return true;
  }

  async saveProgress(): Promise<void> {
    if (this.busy) return;
    if (!this.book.hasLocalFile()) {
      this.message = '尚无本地文件，不能记录阅读进度。';
      return;
    }
    this.busy = true;
    try {
      const locator = `demo:${Math.round(this.progress * 100)}`;
      await this.repository.saveReadingRecord(new ReadingRecord(this.book, this.progress, locator, Date.now()));
      this.message = '演示进度已记录，返回书架可查看阅读历史。';
    } catch {
      this.message = '记录演示进度失败。';
    } finally {
      this.busy = false;
    }
  }
}
