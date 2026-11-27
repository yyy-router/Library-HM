import { AppError } from '../error/AppError';

export enum HttpErrorCode {
  InvalidRequest = 'HTTP_INVALID_REQUEST',
  NotConfigured = 'HTTP_NOT_CONFIGURED',
  Cancelled = 'HTTP_CANCELLED',
  Timeout = 'HTTP_TIMEOUT',
  Network = 'HTTP_NETWORK',
  Status = 'HTTP_STATUS',
  InvalidResponse = 'HTTP_INVALID_RESPONSE',
  InvalidJson = 'HTTP_INVALID_JSON'
}

export class HttpError extends AppError {
  readonly status: number;
  readonly nativeCode: number;

  constructor(code: HttpErrorCode, status: number = 0, nativeCode: number = 0) {
    const messages: Record<string, string> = {
      'HTTP_INVALID_REQUEST': '请求参数无效。', 'HTTP_NOT_CONFIGURED': '网络服务尚未配置。',
      'HTTP_CANCELLED': '请求已取消。', 'HTTP_TIMEOUT': '请求超时，请稍后重试。',
      'HTTP_NETWORK': '网络连接失败，请检查网络或服务地址。', 'HTTP_STATUS': `服务请求失败（HTTP ${status}）。`,
      'HTTP_INVALID_RESPONSE': '服务返回了无法识别的数据。', 'HTTP_INVALID_JSON': '服务未返回有效的 JSON 数据。'
    };
    super(code, messages[code]);
    this.status = status;
    this.nativeCode = nativeCode;
  }
}
