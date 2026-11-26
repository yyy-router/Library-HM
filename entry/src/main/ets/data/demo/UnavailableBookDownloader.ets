import { AppError } from '../../core/error/AppError';
import { Book } from '../../domain/model/Book';
import { LocalBookFile } from '../../domain/model/LocalBookFile';
import { BookDownloader } from '../../domain/service/BookDownloader';

export class UnavailableBookDownloader implements BookDownloader {
  async download(_book: Book, _onProgress: (progress: number) => void): Promise<LocalBookFile> {
    throw new AppError('NOT_IMPLEMENTED', '下载服务尚未接入，书籍已收藏，但尚无本地文件可供阅读。');
  }
}
