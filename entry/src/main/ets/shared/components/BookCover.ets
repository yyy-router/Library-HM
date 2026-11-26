import { Book, BookFormat } from '../../domain/model/Book';
import { ReaderTheme } from '../theme/ReaderTheme';

@Component
export struct BookCover {
  @Prop book: Book = new Book('', '', '', BookFormat.EPUB, '');
  @Prop fixedRatio: number = 0;

  build() {
    Stack() {
      if (this.book.coverAsset.length > 0) {
        Image($rawfile(`covers/${this.book.coverAsset}`))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .draggable(false)
          .accessibilityText(`《${this.book.title}》演示封面`)
      } else {
        Column({ space: 18 }) {
          Text(this.book.format)
            .fontSize(12)
            .fontColor(ReaderTheme.SECONDARY)
          Text(this.book.title)
            .fontSize(24)
            .fontWeight(FontWeight.Medium)
            .fontColor(ReaderTheme.INK)
            .maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .padding(22)
      }
    }
    .width('100%')
    .aspectRatio(this.fixedRatio > 0 ? this.fixedRatio : this.book.coverAspectRatio)
    .backgroundColor(ReaderTheme.SUBTLE)
    .clip(true)
  }
}
