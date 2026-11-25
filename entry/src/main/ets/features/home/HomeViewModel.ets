import { AccountSession } from '../../domain/model/AccountSession';
import { Book } from '../../domain/model/Book';
import { AccountRepository } from '../../domain/repository/AccountRepository';
import { BookCatalogRepository } from '../../domain/repository/BookCatalogRepository';
import { BookshelfRepository } from '../../domain/repository/BookshelfRepository';

@Observed
export class HomeViewModel {
  keyword: string = '';
  email: string = '';
  password: string = '';
  results: Book[] = [];
  session: AccountSession | undefined = undefined;
  busy: boolean = false;
  searched: boolean = false;
  message: string = '';
  private readonly catalog: BookCatalogRepository;
  private readonly bookshelf: BookshelfRepository;
  private readonly account: AccountRepository;

  constructor(catalog: BookCatalogRepository, bookshelf: BookshelfRepository, account: AccountRepository) {
    this.catalog = catalog;
    this.bookshelf = bookshelf;
    this.account = account;
  }

  async loadSession(): Promise<void> {
    try {
      this.session = await this.account.getSession();
    } catch {
      this.message = '暂时无法读取账户状态。';
    }
  }

  async search(): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    this.message = '';
    try {
      this.results = await this.catalog.search(this.keyword);
      this.searched = true;
    } catch {
      this.message = '搜索失败，请稍后重试。';
    } finally {
      this.busy = false;
    }
  }

  async signIn(): Promise<void> {
    if (this.busy) return;
    if (!this.email.trim() || !this.password) {
      this.message = '请填写邮箱和密码；当前登录为占位入口。';
      return;
    }
    const password = this.password;
    this.password = '';
    this.busy = true;
    try {
      this.session = await this.account.signIn(this.email.trim(), password);
      this.message = '登录成功。';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '登录失败。';
    } finally {
      this.busy = false;
    }
  }

  async signOut(): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    try {
      await this.account.signOut();
      this.session = undefined;
      this.password = '';
      this.message = '已退出登录。';
    } catch {
      this.message = '退出登录失败。';
    } finally {
      this.busy = false;
    }
  }

  async addToShelf(book: Book): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    try {
      await this.bookshelf.addBook(book);
      this.message = '演示书籍已加入书架。';
    } catch {
      this.message = '加入书架失败。';
    } finally {
      this.busy = false;
    }
  }
}
