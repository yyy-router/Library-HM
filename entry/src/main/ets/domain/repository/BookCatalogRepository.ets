import { Book } from '../model/Book';

export interface BookCatalogRepository {
  search(keyword: string): Promise<Book[]>;
  // Only the upstream recommendation endpoint may supply this list.
  getRecommended(): Promise<Book[]>;
}
