import { Book, BookFormat } from '../../domain/model/Book';
import { ReaderTheme } from '../theme/ReaderTheme';
import { BookCover } from './BookCover';

@Component
export struct BookItem {
  @Prop book: Book = new Book('', '', '', BookFormat.EPUB, '');
  @Prop actionEnabled: boolean = true;
  @Prop progress: number = 0;
  @Prop lastRead: boolean = false;
  @Prop bookWidth: number = 190;
  onAction: (book: Book) => void = () => {};

  build() {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        BookCover({ book: this.book, fixedRatio: 0.75 })
        if (this.lastRead) {
          Text('上次读到')
            .fontSize(12)
            .fontColor(ReaderTheme.ON_ACCENT)
            .padding({ top: 8, bottom: 10, left: 9, right: 9 })
            .backgroundColor(ReaderTheme.BLUE)
            .borderRadius({ bottomLeft: 6, bottomRight: 6 })
            .margin({ right: 10 })
        }
      }
      .width('100%')
      Column({ space: 5 }) {
        Text(this.book.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(ReaderTheme.INK)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.book.author)
          .fontSize(12)
          .fontColor(ReaderTheme.MUTED)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Blank()
        Row() {
          Text(this.progress >= 1 ? '已读完' : this.progress > 0 ? `已读 ${Math.round(this.progress * 100)}%` : '还未翻开')
            .fontSize(12)
            .fontColor(this.progress > 0 ? ReaderTheme.BLUE : ReaderTheme.MUTED)
            .layoutWeight(1)
          Text(this.book.format)
            .fontSize(12)
            .fontColor(ReaderTheme.MUTED)
        }
        .width('100%')
      }
      .height(106)
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 14, right: 12, top: 14, bottom: 14 })
      .backgroundColor(ReaderTheme.SUBTLE)
      Progress({ value: this.progress * 100, total: 100, type: ProgressType.Linear })
        .width('100%')
        .height(4)
        .style({ strokeWidth: 4 })
        .color(ReaderTheme.BLUE)
        .backgroundColor(ReaderTheme.TRACK)
        .accessibilityText(`阅读进度 ${Math.round(this.progress * 100)}%`)
    }
    .width(this.bookWidth)
    .border({ width: 1, color: ReaderTheme.LINE })
    .borderRadius({ topLeft: 3, topRight: 8, bottomLeft: 3, bottomRight: 7 })
    .backgroundColor(ReaderTheme.SURFACE)
    .clip(true)
    .shadow({ radius: 9, color: ReaderTheme.SHADOW, offsetX: 4, offsetY: 5 })
    .enabled(this.actionEnabled)
    .accessibilityGroup(true)
    .accessibilityText(`打开《${this.book.title}》，已读 ${Math.round(this.progress * 100)}%`)
    .onClick(() => this.onAction(this.book))
  }
}
