import { Book, BookFormat } from '../../domain/model/Book';

@Component
export struct BookItem {
  @Prop book: Book = new Book('', '', '', BookFormat.EPUB, '');
  @Prop actionText: string = '打开';
  @Prop actionEnabled: boolean = true;
  onAction: (book: Book) => void = () => {};

  build() {
    Row({ space: 16 }) {
      Text(this.book.format)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.brand_primary'))
        .width(64)
        .height(84)
        .textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.demo_background'))
        .borderRadius(8)
      Column({ space: 5 }) {
        Text(this.book.title)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.book.author)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
        Text(this.book.isDemo ? '演示书籍' : this.book.format)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Button(this.actionText)
        .fontSize(14)
        .backgroundColor($r('app.color.brand_primary'))
        .enabled(this.actionEnabled)
        .onClick(() => this.onAction(this.book))
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(12)
  }
}
