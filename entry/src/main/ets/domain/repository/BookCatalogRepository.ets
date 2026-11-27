import { Book } from '../model/Book';

export interface BookCatalogRepository {
  search(keyword: string): Promise<Book[]>;
  // Only the upstream recommendation endpoint may supply this list.
  getRecommended(): Promise<Book[]>;
  // 公开热门榜单，与账户个性化推荐分开获取和呈现。
  getPopular(): Promise<Book[]>;
}
