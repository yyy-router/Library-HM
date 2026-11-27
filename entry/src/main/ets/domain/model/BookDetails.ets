import { Book } from './Book';

// 空字符串表示上游未提供该项，不以占位值补齐出版信息。
export class BookDetails {
  readonly book: Book;
  readonly publisher: string;
  readonly year: string;
  readonly language: string;
  readonly pages: string;
  readonly edition: string;
  readonly identifier: string;
  readonly fileSize: string;

  constructor(book: Book, publisher: string = '', year: string = '', language: string = '',
    pages: string = '', edition: string = '', identifier: string = '', fileSize: string = '') {
    this.book = book;
    this.publisher = publisher;
    this.year = year;
    this.language = language;
    this.pages = pages;
    this.edition = edition;
    this.identifier = identifier;
    this.fileSize = fileSize;
  }
}
