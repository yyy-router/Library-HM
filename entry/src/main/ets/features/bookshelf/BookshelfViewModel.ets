import { Book } from '../../domain/model/Book';
import { ReadingRecord } from '../../domain/model/ReadingRecord';
import { BookshelfRepository } from '../../domain/repository/BookshelfRepository';
import { FileImporter } from '../../domain/service/FileImporter';

@Observed
export class BookshelfViewModel {
  books: Book[] = [];
  history: ReadingRecord[] = [];
  busy: boolean = false;
  message: string = '';
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
        this.message = '已添加演示书籍，真实文件选择与解析尚未接入。';
      }
    } catch {
      this.message = '导入失败，请稍后重试。';
    } finally {
      this.busy = false;
    }
  }
}
