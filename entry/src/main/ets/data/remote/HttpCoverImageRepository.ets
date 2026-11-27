import { AppError } from '../../core/error/AppError';
import { HttpClient, isHttpsUrl } from '../../core/network/HttpClient';
import { HttpResponseType } from '../../core/network/HttpTypes';
import { CoverImageRepository, ImageSourceEncoder } from '../../domain/service/CoverImageRepository';

export class HttpCoverImageRepository implements CoverImageRepository {
  private readonly http: HttpClient;
  private readonly encoder: ImageSourceEncoder;
  private readonly cache: Map<string, string> = new Map();
  private readonly pending: Map<string, Promise<string>> = new Map();
  private cachedSize: number = 0;

  constructor(http: HttpClient, encoder: ImageSourceEncoder) { this.http = http; this.encoder = encoder; }

  getCached(url: string): string | undefined {
    const cached = this.cache.get(url);
    if (cached !== undefined) {
      this.cache.delete(url); this.cache.set(url, cached);
    }
    return cached;
  }

  async load(url: string): Promise<string> {
    if (!isHttpsUrl(url)) throw new AppError('INVALID_COVER', '封面地址无效。');
    const cached = this.getCached(url);
    if (cached !== undefined) return cached;
    const existing = this.pending.get(url);
    if (existing) return existing;
    const request = this.fetchImage(url);
    this.pending.set(url, request);
    try { return await request; }
    finally { this.pending.delete(url); }
  }

  private async fetchImage(url: string): Promise<string> {
    const response = await this.http.get(url, { responseType: HttpResponseType.Binary });
    if (!(response.body instanceof ArrayBuffer) || response.body.byteLength > 1024 * 1024) {
      throw new AppError('INVALID_COVER', '封面数据无效或过大。');
    }
    const bytes = new Uint8Array(response.body);
    const mime = this.imageType(bytes);
    if (!mime) throw new AppError('INVALID_COVER', '书源未返回可显示的封面。');
    const source = this.encoder.encode(bytes, mime);
    this.cache.set(url, source); this.cachedSize += source.length;
    // 限制常驻内存；请求失败不缓存，重新进入页面可再次加载。
    while (this.cache.size > 24 || this.cachedSize > 6 * 1024 * 1024) {
      const oldest = this.cache.keys().next().value as string | undefined;
      if (oldest === undefined) break;
      this.cachedSize -= this.cache.get(oldest)?.length ?? 0;
      this.cache.delete(oldest);
    }
    return source;
  }

  private imageType(bytes: Uint8Array): string {
    if (bytes.length < 12) return '';
    if (bytes[0] === 0xFF && bytes[1] === 0xD8 && bytes[2] === 0xFF) return 'image/jpeg';
    if ([137, 80, 78, 71, 13, 10, 26, 10].every((value: number, index: number) => bytes[index] === value)) return 'image/png';
    if (bytes[0] === 82 && bytes[1] === 73 && bytes[2] === 70 && bytes[3] === 70 &&
      bytes[8] === 87 && bytes[9] === 69 && bytes[10] === 66 && bytes[11] === 80) return 'image/webp';
    return '';
  }
}
