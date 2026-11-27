import { CoverImageRepository } from '../../domain/service/CoverImageRepository';
import { BookCover } from '../../shared/components/BookCover';
import { ReaderTheme } from '../../shared/theme/ReaderTheme';
import { BookDetailsViewModel } from './BookDetailsViewModel';
import { StatusMessage } from '../../shared/components/StatusMessage';

@Component
export struct BookDetailsPage {
  @ObjectLink viewModel: BookDetailsViewModel;
  @Prop pageWidth: number = 1000;
  coverImages: CoverImageRepository | undefined = undefined;
  onBack: () => void = () => {};
  onShelf: () => void = () => {};

  private hasMetadata(): boolean {
    const details = this.viewModel.details;
    return details !== undefined && !!(details.publisher || details.year || details.language ||
      details.pages || details.edition || details.identifier || details.fileSize);
  }

  @Builder
  cover() {
    BookCover({ book: this.viewModel.book, fixedRatio: 0.75, coverImages: this.coverImages })
      .width(this.pageWidth > 700 ? 180 : 144)
      .borderRadius(6)
      .shadow({ radius: 10, color: ReaderTheme.SHADOW, offsetX: 3, offsetY: 5 })
  }

  @Builder
  summary() {
    Column({ space: 14 }) {
      Text(this.viewModel.book.title)
        .width('100%')
        .fontSize(this.pageWidth > 700 ? 28 : 23)
        .fontWeight(FontWeight.Bold)
        .fontColor(ReaderTheme.INK)
      if (this.viewModel.book.author) {
        Text(this.viewModel.book.author)
          .width('100%')
          .fontSize(15)
          .lineHeight(24)
          .fontColor(ReaderTheme.SECONDARY)
      }
      Row() {
        if (this.viewModel.book.formatLabel) {
          Text(this.viewModel.book.formatLabel)
            .fontSize(12)
            .fontColor(ReaderTheme.SECONDARY)
            .padding({ left: 9, right: 9, top: 5, bottom: 5 })
            .backgroundColor(ReaderTheme.SUBTLE)
            .borderRadius(5)
        }
      }
      .height(26)
      Button(this.viewModel.saving ? '正在收藏' : this.viewModel.saved ? '前往书架' :
        this.viewModel.shelfLoading ? '正在读取书架' : this.viewModel.shelfReady ? '收藏到书架' : '重试读取书架',
        { type: ButtonType.Normal })
        .fontSize(15)
        .height(46)
        .width(176)
        .padding({ left: 22, right: 22 })
        .borderRadius(12)
        .backgroundColor(ReaderTheme.BLUE)
        .fontColor(ReaderTheme.ON_ACCENT)
        .enabled(!this.viewModel.saving && !this.viewModel.shelfLoading)
        .margin({ top: 8 })
        .onClick(() => {
          if (this.viewModel.saved) this.onShelf();
          else if (!this.viewModel.shelfReady) this.viewModel.refreshShelf();
          else this.viewModel.save();
        })
      Text(this.viewModel.saved ? '已收藏，可前往书架下载或打开已有文件。' : '收藏书目后，可在书架下载。')
        .fontSize(12)
        .lineHeight(21)
        .fontColor(ReaderTheme.MUTED)
      if (this.viewModel.shelfMessage) {
        StatusMessage({ text: this.viewModel.shelfMessage, expiresAt: this.viewModel.shelfMessageExpiresAt,
          messageRevision: this.viewModel.shelfMessageRevision, textLineHeight: 22,
          onExpire: (expiresAt: number, revision: number) => this.viewModel.expireShelfMessage(expiresAt, revision) })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  overview() {
    if (this.pageWidth > 700) {
      Row() {
        this.cover()
        Column() { this.summary() }
          .layoutWeight(1)
          .margin({ left: 32 })
      }
      .alignItems(VerticalAlign.Top)
      .width('100%')
    } else {
      Column({ space: 24 }) {
        this.cover()
        this.summary()
      }
      .width('100%')
    }
  }

  @Builder
  metadataRow(label: string, value: string) {
    if (value) {
      Row({ space: 18 }) {
        Text(label).width(92).fontSize(14).fontColor(ReaderTheme.MUTED)
        Text(value)
          .layoutWeight(1)
          .fontSize(14)
          .lineHeight(23)
          .fontColor(ReaderTheme.INK)
          .copyOption(CopyOptions.InApp)
      }
      .alignItems(VerticalAlign.Top)
      .width('100%')
    }
  }

  build() {
    Column() {
      Row({ space: 18 }) {
        Button('返回', { type: ButtonType.Normal })
          .height(42)
          .padding({ left: 14, right: 14 })
          .borderRadius(10)
          .fontSize(15)
          .backgroundColor(Color.Transparent)
          .fontColor(ReaderTheme.BLUE)
          .accessibilityText('返回图书列表')
          .onClick(() => this.onBack())
        Text('书籍详情').fontSize(17).fontColor(ReaderTheme.INK)
      }
      .width('100%')
      .constraintSize({ maxWidth: 1080 })
      .padding({ left: this.pageWidth > 840 ? 34 : 10, right: 24, top: 14, bottom: 14 })
      Scroll() {
        Column({ space: 24 }) {
          Column() { this.overview() }
            .width('100%')
            .padding(24)
            .backgroundColor(ReaderTheme.SURFACE)
            .border({ width: 1, color: ReaderTheme.LINE })
            .borderRadius(20)
          Column({ space: 16 }) {
            Text('内容简介').fontSize(19).fontWeight(FontWeight.Medium).fontColor(ReaderTheme.INK)
            Text(this.viewModel.book.description || '暂无内容简介。')
              .width('100%')
              .fontSize(15)
              .lineHeight(27)
              .fontColor(ReaderTheme.SECONDARY)
              .copyOption(CopyOptions.InApp)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(24)
          .backgroundColor(ReaderTheme.SURFACE)
          .border({ width: 1, color: ReaderTheme.LINE })
          .borderRadius(20)
          if (this.hasMetadata()) {
            Column({ space: 17 }) {
              Text('出版与文件信息').fontSize(19).fontWeight(FontWeight.Medium).fontColor(ReaderTheme.INK)
              this.metadataRow('出版社', this.viewModel.details?.publisher || '')
              this.metadataRow('出版年份', this.viewModel.details?.year || '')
              this.metadataRow('语言', this.viewModel.details?.language || '')
              this.metadataRow('页数', this.viewModel.details?.pages || '')
              this.metadataRow('版次', this.viewModel.details?.edition || '')
              this.metadataRow('ISBN / 标识', this.viewModel.details?.identifier || '')
              this.metadataRow('文件大小', this.viewModel.details?.fileSize || '')
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(24)
            .backgroundColor(ReaderTheme.SURFACE)
            .border({ width: 1, color: ReaderTheme.LINE })
            .borderRadius(20)
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: 1080 })
        .padding({ left: this.pageWidth > 840 ? 48 : 24, right: this.pageWidth > 840 ? 48 : 24, bottom: 32 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ReaderTheme.BACKGROUND)
  }
}
