import { LocalBookFile } from './LocalBookFile';
import { RemoteBookSource } from './RemoteBookSource';

export enum BookFormat {
  EPUB = 'EPUB',
  PDF = 'PDF',
  Unknown = '未知格式'
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
  readonly source: RemoteBookSource | undefined;

  constructor(id: string, title: string, author: string, format: BookFormat,
    description: string, localUri: string = '', isDemo: boolean = true,
    coverAsset: string = '', coverAspectRatio: number = 0.75, coverBackground: string = '#E8EEE7',
    localFile: LocalBookFile | undefined = undefined, source: RemoteBookSource | undefined = undefined) {
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
    this.source = source;
  }

  hasLocalFile(): boolean {
    return !this.isDemo && this.localFile !== undefined && this.localFile.isValid() &&
      this.localUri === this.localFile.uri;
  }

  get formatLabel(): string { return this.source?.extension || (this.format === BookFormat.Unknown ? '' : this.format); }

  asBookmark(): Book {
    return new Book(this.id, this.title, this.author, this.format, this.description, '', this.isDemo,
      this.coverAsset, this.coverAspectRatio, this.coverBackground, undefined, this.source);
  }

  withLocalFile(file: LocalBookFile): Book {
    return new Book(this.id, this.title, this.author, this.format, this.description, file.uri, false,
      this.coverAsset, this.coverAspectRatio, this.coverBackground, file, this.source);
  }
}
