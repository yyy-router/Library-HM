import { AppConfig } from '../core/config/AppConfig';
import { AppError } from '../core/error/AppError';
import { DemoAccountRepository, DemoBookCatalogRepository, DemoBookshelfRepository } from '../data/demo/DemoRepositories';
import { DemoFileImporter } from '../data/demo/DemoFileImporter';
import { AccountRepository } from '../domain/repository/AccountRepository';
import { BookCatalogRepository } from '../domain/repository/BookCatalogRepository';
import { BookshelfRepository } from '../domain/repository/BookshelfRepository';
import { FileImporter } from '../domain/service/FileImporter';

// 应用级装配入口：后续只在这里替换真实网络、文件与持久化实现。
export class AppContainer {
  readonly catalog: BookCatalogRepository;
  readonly bookshelf: BookshelfRepository;
  readonly account: AccountRepository;
  readonly importer: FileImporter;

  constructor() {
    if (!AppConfig.DEMO_MODE) {
      throw new AppError('NOT_IMPLEMENTED', '真实数据实现尚未配置。');
    }
    this.catalog = new DemoBookCatalogRepository();
    this.bookshelf = new DemoBookshelfRepository();
    this.account = new DemoAccountRepository();
    this.importer = new DemoFileImporter();
  }
}

export const appContainer: AppContainer = new AppContainer();
