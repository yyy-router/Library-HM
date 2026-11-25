import { ReaderViewModel } from './ReaderViewModel';

@Component
export struct ReaderPage {
  @ObjectLink viewModel: ReaderViewModel;
  onBack: () => void = () => {};

  build() {
    Column({ space: 20 }) {
      Row({ space: 16 }) {
        Button('返回书架')
          .fontSize(14)
          .enabled(!this.viewModel.busy)
          .backgroundColor($r('app.color.brand_primary'))
          .onClick(() => this.onBack())
        Text(this.viewModel.book.title)
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .maxLines(2)
      }
      .width('100%')
      Column({ space: 16 }) {
        Text(`${this.viewModel.book.format} 阅读器占位`)
          .fontSize(26)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text('此区域将在后续接入文档渲染，目前不读取真实文件。')
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
        Text(this.viewModel.book.description)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding(28)
      .backgroundColor($r('app.color.surface'))
      .borderRadius(16)
      Text(`演示进度 ${Math.round(this.viewModel.progress * 100)}%`)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
      Slider({ value: this.viewModel.progress * 100, min: 0, max: 100, step: 1 })
        .enabled(!this.viewModel.busy)
        .onChange((value: number) => { this.viewModel.progress = value / 100; })
      Button('保存演示进度')
        .backgroundColor($r('app.color.brand_primary'))
        .enabled(!this.viewModel.busy)
        .onClick(() => { this.viewModel.saveProgress(); })
      Text(this.viewModel.message)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
    }
    .padding(24)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
  }
}
