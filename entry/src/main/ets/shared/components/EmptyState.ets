@Component
export struct EmptyState {
  @Prop title: string = '暂无内容';
  @Prop description: string = '';

  build() {
    Column({ space: 8 }) {
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Text(this.description)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding(28)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(12)
  }
}
