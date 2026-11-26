import { Book } from '../../domain/model/Book';
import { ShelfEntry, ShelfFilter, ShelfRow, ShelfSort } from '../../domain/model/ShelfEntry';
import { BookItem } from '../../shared/components/BookItem';
import { EmptyState } from '../../shared/components/EmptyState';
import { ReaderIcon } from '../../shared/components/ReaderIcon';
import { ReaderTheme } from '../../shared/theme/ReaderTheme';
import { BookshelfViewModel } from './BookshelfViewModel';

@Component
export struct BookshelfPage {
  @ObjectLink viewModel: BookshelfViewModel;
  @Prop pageWidth: number = 1000;
  onOpenBook: (book: Book) => void = () => {};

  private columns(): number { return this.pageWidth > 1100 ? 4 : this.pageWidth > 600 ? 3 : 2; }
  private gap(): number { return this.pageWidth > 1100 ? 42 : 24; }
  private bookWidth(): number {
    const inset = this.pageWidth > 840 ? 96 : 48;
    return Math.min(190, (Math.min(this.pageWidth, 1280) - inset - 40 -
      (this.columns() - 1) * this.gap()) / this.columns());
  }

  private emptySlots(row: ShelfRow): number[] {
    return [0, 1, 2, 3].slice(0, this.columns() - row.entries.length);
  }

  @Builder
  filterButton(label: string, filter: ShelfFilter) {
    Column({ space: 14 }) {
      Row({ space: 6 }) {
        Text(label)
          .fontSize(14)
          .fontWeight(this.viewModel.filter === filter ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.viewModel.filter === filter ? ReaderTheme.INK : ReaderTheme.MUTED)
        if (filter === ShelfFilter.All) {
          Text(`${this.viewModel.books.length}`)
            .fontSize(12)
            .fontColor(ReaderTheme.MUTED)
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .backgroundColor(ReaderTheme.SUBTLE)
            .borderRadius(5)
        }
      }
      Rect().width('100%').height(3)
        .fill(this.viewModel.filter === filter ? ReaderTheme.BLUE : Color.Transparent)
        .radius(2)
    }
    .width(filter === ShelfFilter.All ? 92 : filter === ShelfFilter.Reading ? 82 : 60)
    .padding({ top: 14 })
    .onClick(() => this.viewModel.setFilter(filter))
    .accessibilityText(label)
    .accessibilityDescription(this.viewModel.filter === filter ? '已选中' : '未选中')
  }

  @Builder
  shelfToolbar() {
    Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween,
      alignItems: ItemAlign.Center }) {
      Row({ space: this.pageWidth > 600 ? 28 : 22 }) {
        this.filterButton('全部图书', ShelfFilter.All)
        this.filterButton('正在阅读', ShelfFilter.Reading)
        this.filterButton('已读完', ShelfFilter.Finished)
      }
      Row({ space: 10 }) {
        TextInput({ placeholder: '在书架中搜索', text: this.viewModel.query })
          .fontSize(12)
          .width(this.pageWidth > 600 ? 160 : 145)
          .height(36)
          .fontColor(ReaderTheme.INK)
          .placeholderColor(ReaderTheme.MUTED)
          .backgroundColor(ReaderTheme.SUBTLE)
          .borderRadius(9)
          .onChange((value: string) => this.viewModel.setQuery(value))
        Select([{ value: '最近阅读' }, { value: '书名排序' }, { value: '阅读进度' }])
          .selected(this.viewModel.sort)
          .value(this.viewModel.sort === ShelfSort.Title ? '书名排序' :
            this.viewModel.sort === ShelfSort.Progress ? '阅读进度' : '最近阅读')
          .font({ size: 12 })
          .fontColor(ReaderTheme.MUTED)
          .backgroundColor(ReaderTheme.SURFACE)
          .onSelect((index: number) => this.viewModel.setSort(index))
      }
      .padding({ top: 7, bottom: 7 })
    }
    .width('100%')
    .border({ width: { bottom: 1 }, color: ReaderTheme.LINE })
  }

  @Builder
  shelfRow(row: ShelfRow) {
    Column() {
      Row({ space: this.gap() }) {
        ForEach(row.entries, (entry: ShelfEntry) => {
          Column() {
            BookItem({ book: entry.book, progress: entry.progress,
              downloadState: entry.download.state, downloadProgress: entry.download.progress,
              lastRead: entry.book.id === this.viewModel.lastReadBookId,
              bookWidth: this.bookWidth(), actionEnabled: !this.viewModel.busy,
              onAction: (book: Book) => this.onOpenBook(book),
              onDownload: (book: Book) => { this.viewModel.downloadBook(book); } })
          }
          .layoutWeight(1)
        }, (entry: ShelfEntry) => entry.book.id)
        ForEach(this.emptySlots(row), (slot: number) => {
          Blank().layoutWeight(1)
        }, (slot: number) => `${slot}`)
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
      .padding({ left: 20, right: 20, top: 28 })
      // Rect's default black fill would cover the gradient background on device.
      Row()
        .width('100%')
        .height(14)
        .borderRadius(3)
        .backgroundColor(ReaderTheme.SHELF_MIDDLE)
        .linearGradient({ angle: 180, colors: [[ReaderTheme.SHELF_TOP, 0], [ReaderTheme.SHELF_MIDDLE, 0.5], [ReaderTheme.SHELF_BOTTOM, 1]] })
        .shadow({ radius: 8, color: ReaderTheme.SHADOW, offsetY: 5 })
    }
    .width('100%')
    .linearGradient({ angle: 180, colors: [[ReaderTheme.SURFACE, 0], [ReaderTheme.SUBTLE, 1]] })
    .borderRadius(12)
    .margin({ bottom: 32 })
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row({ space: 12 }) {
          Column({ space: 8 }) {
            Text('我的书架').fontSize(32).fontWeight(FontWeight.Bold).fontColor(ReaderTheme.INK)
            Text(`共 ${this.viewModel.books.length} 本图书 · ${this.viewModel.readingCount} 本正在阅读`)
              .fontSize(13).fontColor(ReaderTheme.SECONDARY)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Button({ type: ButtonType.Normal }) {
            Row({ space: 8 }) {
              ReaderIcon({ name: 'plus', iconSize: 19 })
              Text('导入图书').fontSize(14).fontColor(ReaderTheme.ON_ACCENT)
            }
          }
          .height(46)
          .padding({ left: 20, right: 20 })
          .backgroundColor(ReaderTheme.BLUE)
          .borderRadius(12)
          .enabled(!this.viewModel.busy)
          .onClick(() => { this.viewModel.importBook(); })
        }
        .width('100%')
        .margin({ bottom: 8 })
        this.shelfToolbar()
        if (this.viewModel.message.length > 0) {
          Text(this.viewModel.message).fontSize(13).fontColor(ReaderTheme.BLUE).width('100%')
        }
        if (this.viewModel.entries.length === 0) {
          EmptyState({ title: this.viewModel.books.length > 0 ? '没有符合条件的图书' : '书架还是空的',
            description: this.viewModel.books.length > 0 ? '换个关键词或阅读状态试试。' : '导入图书，或从首页搜索结果加入书架。' })
        } else {
          Column() {
            ForEach(this.viewModel.rows(this.columns()), (row: ShelfRow) => {
              this.shelfRow(row)
            }, (row: ShelfRow) => row.id)
          }
          .width('100%')
        }
        Text('演示书籍与阅读进度仅在本次运行中保留。')
          .fontSize(12)
          .fontColor(ReaderTheme.MUTED)
          .margin({ top: 6, bottom: 20 })
      }
      .width('100%')
      .constraintSize({ maxWidth: 1280 })
      .alignItems(HorizontalAlign.Start)
      .padding({ left: this.pageWidth > 840 ? 48 : 24, right: this.pageWidth > 840 ? 48 : 24, top: 32, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
  }
}
