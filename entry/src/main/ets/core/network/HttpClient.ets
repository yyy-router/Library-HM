import { HttpError, HttpErrorCode } from './HttpError';
import { HttpBody, HttpConfig, HttpHeaders, HttpMethod, HttpOptions, HttpParameter,
  HttpResponse, HttpResponseType, HttpTransport, PreparedHttpRequest } from './HttpTypes';

export function isHttpsUrl(url: string): boolean {
  return /^https:\/\/(?:[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?|\[[0-9a-f:]+\])(?::\d{1,5})?(?:[/?][^\s#\\]*)?$/i.test(url);
}

export class HttpClient {
  private readonly transport: HttpTransport;
  private readonly config: HttpConfig;

  constructor(transport: HttpTransport, config: HttpConfig = new HttpConfig()) {
    this.transport = transport;
    this.config = config;
  }

  get baseUrl(): string { return this.config.baseUrl.replace(/\/+$/, ''); }

  get(path: string, options: HttpOptions = {}): Promise<HttpResponse> {
    return this.request(HttpMethod.GET, path, options);
  }

  postJson(path: string, value: Object, options: HttpOptions = {}): Promise<HttpResponse> {
    let body: string;
    try {
      body = JSON.stringify(value);
      if (typeof body !== 'string') throw new HttpError(HttpErrorCode.InvalidRequest);
    } catch { return Promise.reject(new HttpError(HttpErrorCode.InvalidRequest)); }
    return this.execute(HttpMethod.POST, path, options, body, 'application/json; charset=UTF-8');
  }

  postForm(path: string, fields: HttpParameter[], options: HttpOptions = {}): Promise<HttpResponse> {
    let body: string;
    try { body = this.encode(fields).replace(/%20/g, '+'); }
    catch { return Promise.reject(new HttpError(HttpErrorCode.InvalidRequest)); }
    return this.execute(HttpMethod.POST, path, options, body, 'application/x-www-form-urlencoded; charset=UTF-8');
  }

  request(method: HttpMethod, path: string, options: HttpOptions = {}, body?: HttpBody): Promise<HttpResponse> {
    return this.execute(method, path, options, body);
  }

  private async execute(method: HttpMethod, path: string, options: HttpOptions, body?: HttpBody,
    contentType?: string): Promise<HttpResponse> {
    if (options.cancellation?.cancelled) throw new HttpError(HttpErrorCode.Cancelled);
    if (![HttpMethod.GET, HttpMethod.POST, HttpMethod.PUT, HttpMethod.DELETE, HttpMethod.HEAD].includes(method) ||
      ((method === HttpMethod.GET || method === HttpMethod.HEAD) && body !== undefined)) {
      throw new HttpError(HttpErrorCode.InvalidRequest);
    }
    const headers: HttpHeaders = {};
    this.mergeHeaders(headers, this.config.headers);
    if (options.headers) this.mergeHeaders(headers, options.headers);
    if (contentType) headers['content-type'] = contentType;
    const connect = options.connectTimeoutMs ?? this.config.connectTimeoutMs;
    const read = options.readTimeoutMs ?? this.config.readTimeoutMs;
    if (![connect, read].every((value: number) => Number.isInteger(value) && value > 0 && value <= 60000) ||
      !Number.isInteger(this.config.maxResponseBytes) || this.config.maxResponseBytes < 1 ||
      this.config.maxResponseBytes > 5 * 1024 * 1024) throw new HttpError(HttpErrorCode.InvalidRequest);
    const prepared = new PreparedHttpRequest(this.buildUrl(path, options.query ?? []), method, headers, body,
      connect, read, this.config.maxResponseBytes, options.responseType ?? HttpResponseType.Text);
    let response: HttpResponse;
    try { response = await this.transport.send(prepared, options.cancellation); }
    catch (error) {
      if (options.cancellation?.cancelled) throw new HttpError(HttpErrorCode.Cancelled);
      if (error instanceof HttpError) throw error;
      throw new HttpError(HttpErrorCode.Network);
    }
    if (options.cancellation?.cancelled) throw new HttpError(HttpErrorCode.Cancelled);
    if (!Number.isInteger(response.status) || response.status < 100 || response.status > 599) {
      throw new HttpError(HttpErrorCode.InvalidResponse);
    }
    if ((response.status < 200 || response.status >= 300) && !options.acceptedStatuses?.includes(response.status)) {
      throw new HttpError(HttpErrorCode.Status, response.status);
    }
    return response;
  }

  private buildUrl(path: string, query: HttpParameter[]): string {
    let url: string;
    if (this.baseUrl) {
      this.validateUrl(this.baseUrl);
      if (this.baseUrl.includes('?') || /^[a-z][a-z0-9+.-]*:/i.test(path) || path.startsWith('//')) {
        throw new HttpError(HttpErrorCode.InvalidRequest);
      }
      url = `${this.baseUrl}/${path.replace(/^\//, '')}`;
    } else {
      url = path;
    }
    this.validateUrl(url);
    let encoded: string;
    try { encoded = this.encode(query); } catch { throw new HttpError(HttpErrorCode.InvalidRequest); }
    if (encoded) url += (url.includes('?') ? (/[?&]$/.test(url) ? '' : '&') : '?') + encoded;
    return url;
  }

  private validateUrl(url: string): void {
    if (!isHttpsUrl(url)) {
      throw new HttpError(HttpErrorCode.InvalidRequest);
    }
  }

  private encode(fields: HttpParameter[]): string {
    return fields.map((field: HttpParameter) => `${encodeURIComponent(field.name)}=${encodeURIComponent(field.value)}`).join('&');
  }

  private mergeHeaders(target: HttpHeaders, source: HttpHeaders): void {
    Object.keys(source).forEach((name: string) => {
      if (!/^[!#$%&'*+.^_`|~0-9a-z-]+$/i.test(name) || /[\r\n]/.test(source[name])) {
        throw new HttpError(HttpErrorCode.InvalidRequest);
      }
      target[name.toLowerCase()] = source[name];
    });
  }
}
