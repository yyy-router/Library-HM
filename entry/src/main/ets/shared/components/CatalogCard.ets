import { Book, BookFormat } from '../../domain/model/Book';
import { ReaderTheme } from '../theme/ReaderTheme';
import { BookCover } from './BookCover';
import { ReaderIcon } from './ReaderIcon';
import { CoverImageRepository } from '../../domain/service/CoverImageRepository';

@Component
export struct CatalogCard {
  @Prop book: Book = new Book('', '', '', BookFormat.EPUB, '');
  @Prop actionEnabled: boolean = true;
  @Prop cardWidth: number = 240;
  coverImages: CoverImageRepository | undefined = undefined;
  onSave: (book: Book) => void = () => {};

  build() {
    Column() {
      Column() {
        BookCover({ book: this.book, fixedRatio: 0.75, coverImages: this.coverImages })
          .constraintSize({ maxWidth: 174 })
          .shadow({ radius: 7, color: ReaderTheme.SHADOW, offsetX: 4, offsetY: 5 })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 20, bottom: 20 })
      .backgroundColor(ReaderTheme.SUBTLE)
      Column({ space: 7 }) {
        Text(this.book.title)
          .width('100%')
          .height(44)
          .lineHeight(22)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(ReaderTheme.INK)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.book.author)
          .width('100%')
          .height(18)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontSize(12)
          .fontColor(ReaderTheme.SECONDARY)
        if (this.book.description) {
          Text(this.book.description)
            .width('100%')
            .fontSize(13)
            .fontColor(ReaderTheme.SECONDARY)
            .lineHeight(21)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 5 })
        }
        Row() {
          if (this.book.formatLabel) {
            Text(this.book.formatLabel)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: 72 })
              .fontSize(12)
              .fontColor(ReaderTheme.MUTED)
              .padding({ left: 6, right: 6, top: 4, bottom: 4 })
              .backgroundColor(ReaderTheme.SUBTLE)
              .borderRadius(4)
          }
          Blank()
          Button({ type: ButtonType.Normal }) {
            Row({ space: 5 }) {
              ReaderIcon({ name: 'bookmark', active: true, iconSize: 16 })
              Text('收藏').fontSize(12).fontColor(ReaderTheme.BLUE)
            }
          }
          .width(68)
          .height(34)
          .backgroundColor(ReaderTheme.BLUE_TINT)
          .borderRadius(8)
          .enabled(this.actionEnabled)
          .accessibilityText(`将《${this.book.title}》收藏到书架，下载后可阅读`)
          .onClick(() => this.onSave(this.book))
        }
        .width('100%')
        .margin({ top: 7 })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(14)
    }
    .width(this.cardWidth)
    .borderRadius(17)
    .backgroundColor(ReaderTheme.SURFACE)
    .border({ width: 1, color: ReaderTheme.LINE })
    .clip(true)
  }
}
