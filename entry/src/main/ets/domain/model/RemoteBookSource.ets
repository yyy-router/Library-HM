export class RemoteBookSource {
  readonly origin: string;
  readonly id: string;
  readonly hash: string;
  readonly coverUrl: string;
  readonly extension: string;
  constructor(origin: string, id: string, hash: string, coverUrl: string = '', extension: string = '') {
    this.origin = origin; this.id = id; this.hash = hash; this.coverUrl = coverUrl; this.extension = extension;
  }
}
