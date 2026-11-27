import { AccountSession } from '../../domain/model/AccountSession';
import { Book } from '../../domain/model/Book';
import { AccountRepository } from '../../domain/repository/AccountRepository';
import { BookCatalogRepository } from '../../domain/repository/BookCatalogRepository';
import { BookshelfRepository } from '../../domain/repository/BookshelfRepository';
import { AppError } from '../../core/error/AppError';

export enum RecommendationState {
  Loading, Unconfigured, Ready, Error
}

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
  loginMessage: string = '';
  recommendations: Book[] = [];
  recommendationState: RecommendationState = RecommendationState.Loading;
  recommendationMessage: string = '';
  listRevision: number = 0;
  private recommendationVersion: number = 0;
  private searchVersion: number = 0;
  private searching: boolean = false;
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
      await this.loadRecommendations();
    } catch (error) {
      if (error instanceof AppError && error.code === 'AUTH_REQUIRED') this.clearAccount();
      this.message = error instanceof AppError ? error.message : '暂时无法读取账户状态。';
      await this.loadRecommendations();
    }
  }

  async loadRecommendations(): Promise<void> {
    const version = ++this.recommendationVersion;
    const personalized = this.session !== undefined;
    this.recommendations = [];
    this.listRevision++;
    this.recommendationMessage = '';
    this.recommendationState = RecommendationState.Loading;
    try {
      const books = personalized ? await this.catalog.getRecommended() : await this.catalog.getPopular();
      if (version !== this.recommendationVersion) return;
      this.recommendations = books;
      this.recommendationState = RecommendationState.Ready;
    } catch (error) {
      if (version !== this.recommendationVersion) return;
      if (personalized && error instanceof AppError && error.code === 'AUTH_REQUIRED') {
        this.clearAccount(); this.message = error.message; await this.loadRecommendations(); return;
      }
      this.recommendationState = error instanceof AppError && error.code === 'NOT_IMPLEMENTED' ?
        RecommendationState.Unconfigured : RecommendationState.Error;
      this.recommendationMessage = error instanceof AppError ? error.message : '获取书目失败，请稍后重试。';
    }
  }

  clearSearch(): void {
    this.searchVersion++;
    if (this.searching) {
      this.searching = false;
      this.busy = false;
    }
    this.keyword = '';
    this.results = [];
    this.searched = false;
    this.message = '';
  }

  clearLoginDraft(): void {
    this.email = '';
    this.password = '';
    this.loginMessage = '';
  }

  async search(): Promise<void> {
    if (this.busy) return;
    const version = ++this.searchVersion;
    this.searching = true;
    this.busy = true;
    this.message = '';
    try {
      const results = await this.catalog.search(this.keyword);
      if (version !== this.searchVersion) return;
      this.results = results;
      this.listRevision++;
      this.searched = true;
    } catch (error) {
      if (version === this.searchVersion) {
        if (error instanceof AppError && error.code === 'AUTH_REQUIRED') {
          this.clearAccount(); await this.loadRecommendations();
        }
        this.message = error instanceof AppError ? error.message : '搜索失败，请稍后重试。';
      }
    } finally {
      if (version === this.searchVersion) {
        this.searching = false;
        this.busy = false;
      }
    }
  }

  async signIn(): Promise<void> {
    if (this.busy) return;
    if (!this.email.trim() || !this.password) {
      this.loginMessage = '请填写邮箱和密码。';
      this.message = this.loginMessage;
      return;
    }
    const password = this.password;
    this.password = '';
    this.busy = true;
    this.loginMessage = '';
    try {
      this.session = await this.account.signIn(this.email.trim(), password);
      this.clearSearch();
      this.message = '登录成功。';
      this.email = '';
      await this.loadRecommendations();
    } catch (error) {
      this.loginMessage = error instanceof Error ? error.message : '登录失败。';
      this.message = this.loginMessage;
    } finally {
      this.busy = false;
    }
  }

  async signOut(): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    try {
      await this.account.signOut();
      this.clearAccount();
      this.clearLoginDraft();
      await this.loadRecommendations();
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
      await this.bookshelf.addBook(book.asBookmark());
      this.message = '已收藏到书架，下载后即可阅读。';
    } catch {
      this.message = '加入书架失败。';
    } finally {
      this.busy = false;
    }
  }

  private clearAccount(): void {
    this.session = undefined;
    this.clearSearch();
    this.recommendationVersion++;
    this.recommendations = [];
    this.recommendationState = RecommendationState.Loading;
    this.recommendationMessage = '';
  }
}
