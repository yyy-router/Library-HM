import { Book, BookFormat } from '../../domain/model/Book';
import { ReaderTheme } from '../theme/ReaderTheme';
import { CoverImageRepository } from '../../domain/service/CoverImageRepository';

@Component
export struct BookCover {
  @Prop @Watch('reloadCover') book: Book = new Book('', '', '', BookFormat.EPUB, '');
  @Prop fixedRatio: number = 0;
  coverImages: CoverImageRepository | undefined = undefined;
  @State private remoteImage: string = '';
  private loadVersion: number = 0;
  private visible: boolean = false;

  aboutToAppear(): void { this.visible = true; this.reloadCover(); }
  aboutToDisappear(): void { this.visible = false; this.loadVersion++; }

  private reloadCover(): void {
    const version = ++this.loadVersion;
    this.remoteImage = '';
    const url = this.book.source?.coverUrl;
    if (!this.visible || this.book.coverAsset || !url || !this.coverImages) return;
    this.coverImages.load(url).then((source: string) => {
      if (this.visible && version === this.loadVersion) this.remoteImage = source;
    }).catch(() => {
      // 保留书名占位；不因封面失败影响搜索、收藏或书架。
    });
  }

  build() {
    Stack() {
      if (this.remoteImage) {
        Image(this.remoteImage)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .draggable(false)
          .accessibilityText(`《${this.book.title}》封面`)
          .onError(() => { this.remoteImage = ''; })
      } else if (this.book.coverAsset.length > 0) {
        Image($rawfile(`covers/${this.book.coverAsset}`))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .draggable(false)
          .accessibilityText(`《${this.book.title}》演示封面`)
      } else {
        Column({ space: 18 }) {
          if (this.book.formatLabel) {
            Text(this.book.formatLabel)
              .fontSize(12)
              .fontColor(ReaderTheme.SECONDARY)
          }
          Text(this.book.title)
            .fontSize(19)
            .fontWeight(FontWeight.Medium)
            .fontColor(ReaderTheme.INK)
            .maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(16)
      }
    }
    .width('100%')
    .aspectRatio(this.fixedRatio > 0 ? this.fixedRatio : this.book.coverAspectRatio)
    .backgroundColor(ReaderTheme.SUBTLE)
    .clip(true)
  }
}
