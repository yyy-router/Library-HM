import { AppError } from '../../core/error/AppError';
import { HttpClient, isHttpsUrl } from '../../core/network/HttpClient';
import { HttpError, HttpErrorCode } from '../../core/network/HttpError';
import { HttpHeaders, HttpOptions, HttpParameter, HttpResponse } from '../../core/network/HttpTypes';
import { Book } from '../../domain/model/Book';
import { EapiEnvelope, readText } from './EapiTypes';
import { EapiSessionStore } from './EapiSessionStore';

export class EapiClient {
  readonly http: HttpClient;
  readonly sessions: EapiSessionStore;

  constructor(http: HttpClient, sessions: EapiSessionStore) { this.http = http; this.sessions = sessions; }

  async get(path: string): Promise<EapiEnvelope> { return this.authenticated(path); }
  async post(path: string, fields: HttpParameter[]): Promise<EapiEnvelope> { return this.authenticated(path, fields); }

  async getPublic(path: string): Promise<EapiEnvelope> {
    const result = (await this.http.get(path)).json<EapiEnvelope>();
    if (!result || typeof result !== 'object' || Array.isArray(result)) {
      throw new AppError('INVALID_RESPONSE', '书源返回的数据格式无效。');
    }
    if (result.success !== 1 && result.success !== true) {
      throw new AppError('REMOTE_REJECTED', '书源未接受请求，请稍后重试。');
    }
    return result;
  }

  private async authenticated(path: string, fields?: HttpParameter[], allowAnonymous: boolean = false,
    options: HttpOptions = {}): Promise<EapiEnvelope> {
    await this.sessions.restore();
    const signedIn = this.sessions.display !== undefined;
    const headers: HttpHeaders = allowAnonymous && !signedIn ? {} : this.sessions.headers();
    const version = this.sessions.version;
    const authMessage = signedIn ? '登录已失效，请重新登录。' : '此操作需要登录，请先在首页登录。';
    const requestOptions: HttpOptions = { headers: headers, acceptedStatuses: [401, 403],
      connectTimeoutMs: options.connectTimeoutMs, readTimeoutMs: options.readTimeoutMs };
    let response: HttpResponse;
    try {
      response = fields ? await this.http.postForm(path, fields, requestOptions) : await this.http.get(path, requestOptions);
    } catch (error) {
      if (error instanceof HttpError && error.status === 401 && version === this.sessions.version) {
        await this.sessions.clear();
        throw new AppError('AUTH_REQUIRED', authMessage);
      }
      if (error instanceof AppError) throw error;
      throw new AppError('NETWORK_ERROR', '网络请求失败，请稍后重试。');
    }
    if (version !== this.sessions.version) throw new AppError('REQUEST_SUPERSEDED', '会话已改变，请重新操作。');
    if (response.status === 401) {
      await this.sessions.clear();
      throw new AppError('AUTH_REQUIRED', authMessage);
    }
    let result: EapiEnvelope;
    try { result = response.json<EapiEnvelope>(); }
    catch (error) {
      if (response.status === 403) throw new HttpError(HttpErrorCode.Status, 403);
      if (error instanceof AppError) throw error;
      throw new HttpError(HttpErrorCode.InvalidJson);
    }
    if (!result || typeof result !== 'object' || Array.isArray(result)) {
      throw new AppError('INVALID_RESPONSE', '书源返回的数据格式无效。');
    }
    if (result.success !== 1 && result.success !== true) {
      if (/please login|not logged|authorization failed|invalid credentials/i.test(readText(result.error))) {
        await this.sessions.clear();
        throw new AppError('AUTH_REQUIRED', authMessage);
      }
      if (response.status === 403) throw new HttpError(HttpErrorCode.Status, 403);
      throw new AppError('REMOTE_REJECTED', '书源未接受请求，请检查账户状态或稍后重试。');
    }
    if (response.status === 403) throw new HttpError(HttpErrorCode.Status, 403);
    return result;
  }

  bookPath(book: Book): string {
    const source = book.source;
    if (!source || source.origin !== this.http.baseUrl || !source.id || !source.hash) {
      throw new AppError('INVALID_BOOK_SOURCE', '书籍缺少当前书源的有效标识，暂时无法获取详情或下载。');
    }
    return `/eapi/book/${encodeURIComponent(source.id)}/${encodeURIComponent(source.hash)}`;
  }

  async getBookDetails(book: Book): Promise<EapiEnvelope> {
    // 详情允许匿名访问；存在会话时沿用鉴权与版本检查，不回退或重发请求。
    return this.authenticated(this.bookPath(book), undefined, true, { connectTimeoutMs: 30000, readTimeoutMs: 60000 });
  }

  async getDownloadLink(book: Book): Promise<string> {
    const result = await this.get(`${this.bookPath(book)}/file`);
    const link = readText(result.file?.downloadLink) || readText(result.downloadLink) || readText(result.url) || readText(result.link);
    const url = /^[a-z][a-z0-9+.-]*:/i.test(link) ? link :
      link.startsWith('//') ? '' : `${this.http.baseUrl}/${link.replace(/^\//, '')}`;
    if (!link || !isHttpsUrl(url)) throw new AppError('INVALID_DOWNLOAD_LINK', '书源未返回有效的 HTTPS 下载地址。');
    // The caller must use an unauthenticated client for the file host, never forward these API headers.
    return url;
  }
}
