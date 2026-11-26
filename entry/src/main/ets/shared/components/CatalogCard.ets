import { Book, BookFormat } from '../../domain/model/Book';
import { ReaderTheme } from '../theme/ReaderTheme';
import { BookCover } from './BookCover';
import { ReaderIcon } from './ReaderIcon';

@Component
export struct CatalogCard {
  @Prop book: Book = new Book('', '', '', BookFormat.EPUB, '');
  @Prop actionEnabled: boolean = true;
  onSave: (book: Book) => void = () => {};

  build() {
    Column() {
      Column() {
        BookCover({ book: this.book })
          .constraintSize({ maxWidth: 174 })
          .shadow({ radius: 7, color: ReaderTheme.SHADOW, offsetX: 4, offsetY: 5 })
      }
      .width('100%')
      .padding({ left: 26, right: 26, top: 24, bottom: 22 })
      .backgroundColor(ReaderTheme.SUBTLE)
      Column({ space: 7 }) {
        Text(this.book.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(ReaderTheme.INK)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.book.author)
          .fontSize(12)
          .fontColor(ReaderTheme.SECONDARY)
        Text(this.book.description)
          .fontSize(13)
          .fontColor(ReaderTheme.SECONDARY)
          .lineHeight(23)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 5 })
        Row() {
          Text(this.book.format)
            .fontSize(12)
            .fontColor(ReaderTheme.MUTED)
            .padding({ left: 6, right: 6, top: 4, bottom: 4 })
            .backgroundColor(ReaderTheme.SUBTLE)
            .borderRadius(4)
          Blank()
          Button({ type: ButtonType.Normal }) {
            ReaderIcon({ name: 'bookmark', active: true, iconSize: 18 })
          }
          .width(34)
          .height(34)
          .backgroundColor(ReaderTheme.BLUE_TINT)
          .borderRadius(8)
          .enabled(this.actionEnabled)
          .accessibilityText(`将《${this.book.title}》加入书架`)
          .onClick(() => this.onSave(this.book))
        }
        .width('100%')
        .margin({ top: 7 })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(17)
    }
    .width('100%')
    .borderRadius(17)
    .backgroundColor(ReaderTheme.SURFACE)
    .border({ width: 1, color: ReaderTheme.LINE })
    .clip(true)
  }
}
