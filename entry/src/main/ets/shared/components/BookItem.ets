import { Book, BookFormat } from '../../domain/model/Book';
import { DownloadState } from '../../domain/model/ShelfEntry';
import { ReaderTheme } from '../theme/ReaderTheme';
import { BookCover } from './BookCover';
import { CoverImageRepository } from '../../domain/service/CoverImageRepository';

@Component
export struct BookItem {
  @Prop book: Book = new Book('', '', '', BookFormat.EPUB, '');
  @Prop actionEnabled: boolean = true;
  coverImages: CoverImageRepository | undefined = undefined;
  @Prop progress: number = 0;
  @Prop lastRead: boolean = false;
  @Prop bookWidth: number = 190;
  @Prop downloadState: DownloadState = DownloadState.NotDownloaded;
  @Prop downloadProgress: number = 0;
  onAction: (book: Book) => void = () => {};
  onDownload: (book: Book) => void = () => {};

  private actionLabel(): string {
    if (this.book.hasLocalFile()) return this.progress > 0 ? '继续阅读' : '开始阅读';
    if (this.downloadState === DownloadState.Downloading) return `下载中 ${Math.round(this.downloadProgress * 100)}%`;
    return this.downloadState === DownloadState.Failed ? '重试下载' : '下载';
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        BookCover({ book: this.book, fixedRatio: 0.75, coverImages: this.coverImages })
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
          Text(this.progress >= 1 ? '已读完' : this.progress > 0 ? `已读 ${Math.round(this.progress * 100)}%` :
            this.book.hasLocalFile() ? '还未翻开' : '未下载')
            .fontSize(12)
            .fontColor(this.progress > 0 ? ReaderTheme.BLUE : ReaderTheme.MUTED)
            .layoutWeight(1)
          if (this.book.formatLabel) {
            Text(this.book.formatLabel)
              .maxLines(1)
              .constraintSize({ maxWidth: 66 })
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontSize(12)
              .fontColor(ReaderTheme.MUTED)
          }
        }
        .width('100%')
        Button(this.actionLabel(), { type: ButtonType.Normal })
          .width('100%')
          .height(30)
          .fontSize(12)
          .fontColor(ReaderTheme.BLUE)
          .backgroundColor(ReaderTheme.BLUE_TINT)
          .borderRadius(6)
          .enabled(this.downloadState !== DownloadState.Downloading)
          .accessibilityText(`${this.actionLabel()}《${this.book.title}》`)
          .onClick(() => {
            if (this.book.hasLocalFile()) this.onAction(this.book);
            else this.onDownload(this.book);
          })
      }
      .height(148)
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 14, right: 12, top: 14, bottom: 14 })
      .backgroundColor(ReaderTheme.SUBTLE)
      Progress({ value: (this.downloadState === DownloadState.Downloading ?
        this.downloadProgress : this.progress) * 100, total: 100, type: ProgressType.Linear })
        .width('100%')
        .height(4)
        .style({ strokeWidth: 4 })
        .color(ReaderTheme.BLUE)
        .backgroundColor(ReaderTheme.TRACK)
        .accessibilityText(this.downloadState === DownloadState.Downloading ?
          `下载进度 ${Math.round(this.downloadProgress * 100)}%` : `阅读进度 ${Math.round(this.progress * 100)}%`)
    }
    .width(this.bookWidth)
    .border({ width: 1, color: ReaderTheme.LINE })
    .borderRadius({ topLeft: 3, topRight: 8, bottomLeft: 3, bottomRight: 7 })
    .backgroundColor(ReaderTheme.SURFACE)
    .clip(true)
    .shadow({ radius: 9, color: ReaderTheme.SHADOW, offsetX: 4, offsetY: 5 })
    .enabled(this.actionEnabled)
    .accessibilityDescription(this.book.hasLocalFile() ? '已有本地文件' : '已收藏，下载后可阅读')
  }
}
