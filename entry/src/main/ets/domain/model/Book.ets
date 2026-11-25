export enum BookFormat {
  EPUB = 'EPUB',
  PDF = 'PDF'
}

export class Book {
  readonly id: string;
  readonly title: string;
  readonly author: string;
  readonly format: BookFormat;
  readonly description: string;
  readonly localUri: string;
  readonly isDemo: boolean;

  constructor(id: string, title: string, author: string, format: BookFormat,
    description: string, localUri: string = '', isDemo: boolean = true) {
    this.id = id;
    this.title = title;
    this.author = author;
    this.format = format;
    this.description = description;
    this.localUri = localUri;
    this.isDemo = isDemo;
  }
}
