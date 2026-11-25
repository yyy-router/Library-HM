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
  readonly coverAsset: string;
  readonly coverAspectRatio: number;
  readonly coverBackground: string;

  constructor(id: string, title: string, author: string, format: BookFormat,
    description: string, localUri: string = '', isDemo: boolean = true,
    coverAsset: string = '', coverAspectRatio: number = 0.75, coverBackground: string = '#E8EEE7') {
    this.id = id;
    this.title = title;
    this.author = author;
    this.format = format;
    this.description = description;
    this.localUri = localUri;
    this.isDemo = isDemo;
    this.coverAsset = coverAsset;
    this.coverAspectRatio = coverAspectRatio;
    this.coverBackground = coverBackground;
  }
}
