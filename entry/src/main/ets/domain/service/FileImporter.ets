import { Book } from '../model/Book';

export interface FileImporter {
  // 真实实现应复制文件到应用可持续访问的位置，检查存在且非空后附带 LocalBookFile。
  importBook(): Promise<Book | undefined>;
}
