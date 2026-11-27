import { Book, BookFormat } from '../../domain/model/Book';
import { ReaderTheme } from '../theme/ReaderTheme';
import { CoverImageRepository } from '../../domain/service/CoverImageRepository';
import { BookCoverViewModel } from './BookCoverViewModel';

@Component
export struct BookCover {
  @Prop @Watch('reloadCover') book: Book = new Book('', '', '', BookFormat.EPUB, '');
  @Prop fixedRatio: number = 0;
  coverImages: CoverImageRepository | undefined = undefined;
  @State private cover: BookCoverViewModel = new BookCoverViewModel();
  private visible: boolean = false;

  aboutToAppear(): void { this.visible = true; this.reloadCover(); }
  aboutToDisappear(): void { this.visible = false; this.cover.close(); }

  private reloadCover(): void {
    if (this.visible) this.cover.update(this.book, this.coverImages);
  }

  build() {
    Stack() {
      if (this.cover.image) {
        Image(this.cover.image)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .draggable(false)
          .accessibilityText(`《${this.book.title}》封面`)
          .onError(() => this.cover.clearFailedImage())
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
