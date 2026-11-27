import { Book } from '../model/Book';
import { BookDetails } from '../model/BookDetails';

export interface BookCatalogRepository {
  search(keyword: string): Promise<Book[]>;
  getDetails(book: Book): Promise<BookDetails>;
  // Only the upstream recommendation endpoint may supply this list.
  getRecommended(): Promise<Book[]>;
  // 公开热门榜单，与账户个性化推荐分开获取和呈现。
  getPopular(): Promise<Book[]>;
}
