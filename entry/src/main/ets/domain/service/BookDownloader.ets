import { Book } from '../model/Book';
import { LocalBookFile } from '../model/LocalBookFile';

export interface BookDownloader {
  // 返回前必须把文件保存到应用可持续访问的位置，检查存在且非空。
  // 失败时清理临时文件并抛错；不得把下载 URL 当作本地文件返回。
  download(book: Book, onProgress: (progress: number) => void): Promise<LocalBookFile>;
}
