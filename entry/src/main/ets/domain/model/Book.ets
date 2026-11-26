import { LocalBookFile } from './LocalBookFile';

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
  readonly localFile: LocalBookFile | undefined;

  constructor(id: string, title: string, author: string, format: BookFormat,
    description: string, localUri: string = '', isDemo: boolean = true,
    coverAsset: string = '', coverAspectRatio: number = 0.75, coverBackground: string = '#E8EEE7',
    localFile: LocalBookFile | undefined = undefined) {
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
    this.localFile = localFile;
  }

  hasLocalFile(): boolean {
    return !this.isDemo && this.localFile !== undefined && this.localFile.isValid() &&
      this.localUri === this.localFile.uri;
  }

  asBookmark(): Book {
    return new Book(this.id, this.title, this.author, this.format, this.description, '', this.isDemo,
      this.coverAsset, this.coverAspectRatio, this.coverBackground);
  }

  withLocalFile(file: LocalBookFile): Book {
    return new Book(this.id, this.title, this.author, this.format, this.description, file.uri, false,
      this.coverAsset, this.coverAspectRatio, this.coverBackground, file);
  }
}
