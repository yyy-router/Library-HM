import { Book } from '../../domain/model/Book';
import { ReadingRecord } from '../../domain/model/ReadingRecord';
import { BookItem } from '../../shared/components/BookItem';
import { EmptyState } from '../../shared/components/EmptyState';
import { BookshelfViewModel } from './BookshelfViewModel';

@Component
export struct BookshelfPage {
  @ObjectLink viewModel: BookshelfViewModel;
  onOpenBook: (book: Book) => void = () => {};

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row({ space: 16 }) {
          Text('我的书架')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Button('导入书籍（演示）')
            .fontSize(14)
            .backgroundColor($r('app.color.brand_primary'))
            .enabled(!this.viewModel.busy)
            .onClick(() => { this.viewModel.importBook(); })
        }
        .width('100%')
        Text('演示内容与阅读历史仅在本次运行中保留。')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        if (this.viewModel.message.length > 0) {
          Text(this.viewModel.message)
            .fontSize(14)
            .fontColor($r('app.color.brand_primary'))
            .width('100%')
        }
        Text('已导入书籍')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        if (this.viewModel.books.length === 0) {
          EmptyState({ title: '书架还是空的', description: '导入一本书，或从首页搜索结果加入书架。' })
        } else {
          ForEach(this.viewModel.books, (book: Book) => {
            BookItem({
              book: book,
              actionText: '打开',
              actionEnabled: !this.viewModel.busy,
              onAction: (selected: Book) => this.onOpenBook(selected)
            })
          }, (book: Book) => book.id)
        }
        Text('阅读历史')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .margin({ top: 12 })
        if (this.viewModel.history.length === 0) {
          EmptyState({ title: '暂无阅读历史', description: '打开书籍并保存演示进度后，记录会显示在这里。' })
        } else {
          ForEach(this.viewModel.history, (record: ReadingRecord) => {
            Column({ space: 8 }) {
              BookItem({
                book: record.book,
                actionText: '继续阅读',
                onAction: (selected: Book) => this.onOpenBook(selected)
              })
              Text(`演示进度 ${Math.round(record.progress * 100)}% · ${new Date(record.updatedAt).toLocaleString()}`)
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
            }
          }, (record: ReadingRecord) => record.book.id)
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: 1100 })
      .alignItems(HorizontalAlign.Start)
      .padding(24)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
  }
}
