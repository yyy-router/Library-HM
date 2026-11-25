import { Book } from '../model/Book';

export interface BookCatalogRepository {
  search(keyword: string): Promise<Book[]>;
}
