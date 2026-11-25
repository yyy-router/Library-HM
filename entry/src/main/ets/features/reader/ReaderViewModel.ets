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

  async open(book: Book): Promise<void> {
    this.book = book;
    this.progress = 0;
    this.message = '';
    this.busy = true;
    try {
      const record = await this.repository.getReadingRecord(book.id);
      this.progress = record ? record.progress : 0;
    } catch {
      this.message = '读取演示进度失败。';
    } finally {
      this.busy = false;
    }
  }

  async saveProgress(): Promise<void> {
    if (this.busy) return;
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
