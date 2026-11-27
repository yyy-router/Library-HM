import { AppError } from '../../core/error/AppError';
import { Book } from '../../domain/model/Book';
import { LocalBookFile } from '../../domain/model/LocalBookFile';
import { BookDownloader } from '../../domain/service/BookDownloader';

export class UnavailableBookDownloader implements BookDownloader {
  async download(_book: Book, _onProgress: (progress: number) => void): Promise<LocalBookFile> {
    throw new AppError('NOT_IMPLEMENTED', '文件下载与保存尚未接入，收藏的书籍需下载后阅读。');
  }
}
