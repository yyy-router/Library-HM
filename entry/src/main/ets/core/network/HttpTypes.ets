import { CancellationToken } from './CancellationToken';
import { HttpError, HttpErrorCode } from './HttpError';

export enum HttpMethod { GET = 'GET', POST = 'POST', PUT = 'PUT', DELETE = 'DELETE', HEAD = 'HEAD' }
export enum HttpResponseType { Text, Binary }
export type HttpBody = string | ArrayBuffer;
export type HttpHeaders = Record<string, string>;
export type HttpResponseHeaders = Record<string, string | string[]>;

export class HttpParameter {
  readonly name: string;
  readonly value: string;
  constructor(name: string, value: string) { this.name = name; this.value = value; }
}

export interface HttpOptions {
  query?: HttpParameter[];
  headers?: HttpHeaders;
  connectTimeoutMs?: number;
  readTimeoutMs?: number;
  responseType?: HttpResponseType;
  cancellation?: CancellationToken;
  acceptedStatuses?: number[];
}

export class HttpConfig {
  baseUrl: string = '';
  connectTimeoutMs: number = 10000;
  readTimeoutMs: number = 30000;
  maxResponseBytes: number = 5 * 1024 * 1024;
  headers: HttpHeaders = { 'accept': 'application/json' };
}

export class PreparedHttpRequest {
  readonly url: string;
  readonly method: HttpMethod;
  readonly headers: HttpHeaders;
  readonly body: HttpBody | undefined;
  readonly connectTimeoutMs: number;
  readonly readTimeoutMs: number;
  readonly maxResponseBytes: number;
  readonly responseType: HttpResponseType;

  constructor(url: string, method: HttpMethod, headers: HttpHeaders, body: HttpBody | undefined,
    connectTimeoutMs: number, readTimeoutMs: number, maxResponseBytes: number, responseType: HttpResponseType) {
    this.url = url; this.method = method; this.headers = headers; this.body = body;
    this.connectTimeoutMs = connectTimeoutMs; this.readTimeoutMs = readTimeoutMs;
    this.maxResponseBytes = maxResponseBytes; this.responseType = responseType;
  }
}

export class HttpResponse {
  readonly status: number;
  readonly body: HttpBody;
  readonly headers: HttpResponseHeaders;
  readonly cookies: string;

  constructor(status: number, body: HttpBody, headers: HttpResponseHeaders = {}, cookies: string = '') {
    this.status = status; this.body = body; this.headers = headers; this.cookies = cookies;
  }

  text(): string {
    if (typeof this.body !== 'string') throw new HttpError(HttpErrorCode.InvalidResponse);
    return this.body;
  }

  json<T>(): T {
    const text = this.text();
    try { return JSON.parse(text) as T; } catch { throw new HttpError(HttpErrorCode.InvalidJson); }
  }
}

export interface HttpTransport {
  send(request: PreparedHttpRequest, cancellation?: CancellationToken): Promise<HttpResponse>;
}

// Pure-logic callers must inject a transport; this fallback never fabricates a response.
export class UnconfiguredHttpTransport implements HttpTransport {
  async send(_request: PreparedHttpRequest, _cancellation?: CancellationToken): Promise<HttpResponse> {
    throw new HttpError(HttpErrorCode.NotConfigured);
  }
}
