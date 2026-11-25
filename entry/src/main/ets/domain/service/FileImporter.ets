import { Book } from '../model/Book';

export interface FileImporter {
  importBook(): Promise<Book | undefined>;
}
