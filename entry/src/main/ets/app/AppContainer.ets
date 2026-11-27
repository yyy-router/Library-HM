import { AppConfig } from '../core/config/AppConfig';
import { HttpClient } from '../core/network/HttpClient';
import { HttpConfig, HttpTransport, UnconfiguredHttpTransport } from '../core/network/HttpTypes';
import { MemoryBookshelfRepository } from '../data/local/MemoryBookshelfRepository';
import { UnavailableFileImporter } from '../data/local/UnavailableFileImporter';
import { EapiAccountRepository } from '../data/remote/EapiAccountRepository';
import { EapiBookCatalogRepository } from '../data/remote/EapiBookCatalogRepository';
import { EapiClient } from '../data/remote/EapiClient';
import { EapiSessionStore } from '../data/remote/EapiSessionStore';
import { MemorySessionVault, SessionVault } from '../core/security/SessionVault';
import { AccountRepository } from '../domain/repository/AccountRepository';
import { BookCatalogRepository } from '../domain/repository/BookCatalogRepository';
import { BookshelfRepository } from '../domain/repository/BookshelfRepository';
import { FileImporter } from '../domain/service/FileImporter';
import { BookDownloader } from '../domain/service/BookDownloader';
import { UnavailableBookDownloader } from '../data/local/UnavailableBookDownloader';

// 应用级装配入口：后续只在这里替换真实网络、文件与持久化实现。
export class AppContainer {
  readonly http: HttpClient;
  readonly api: EapiClient;
  readonly catalog: BookCatalogRepository;
  readonly bookshelf: BookshelfRepository;
  readonly account: AccountRepository;
  readonly importer: FileImporter;
  readonly downloader: BookDownloader;

  constructor(transport: HttpTransport = new UnconfiguredHttpTransport(), baseUrl: string = AppConfig.API_BASE_URL,
    vault: SessionVault = new MemorySessionVault()) {
    const config = new HttpConfig();
    config.baseUrl = baseUrl;
    config.headers = { 'accept': 'application/json', 'source': 'android' };
    this.http = new HttpClient(transport, config);
    this.api = new EapiClient(this.http, new EapiSessionStore(vault, baseUrl));
    this.catalog = new EapiBookCatalogRepository(this.api);
    this.bookshelf = new MemoryBookshelfRepository();
    this.account = new EapiAccountRepository(this.api);
    this.importer = new UnavailableFileImporter();
    this.downloader = new UnavailableBookDownloader();
  }
}
