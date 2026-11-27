import { AppError } from '../../core/error/AppError';
import { Book } from '../../domain/model/Book';
import { FileImporter } from '../../domain/service/FileImporter';

export class UnavailableFileImporter implements FileImporter {
  async importBook(): Promise<Book | undefined> {
    throw new AppError('NOT_IMPLEMENTED', '本地文件导入尚未接入。');
  }
}
