import { ReaderIcon } from '../../shared/components/ReaderIcon';
import { ReaderTheme } from '../../shared/theme/ReaderTheme';
import { HomeViewModel } from './HomeViewModel';

@CustomDialog
export struct LoginDialog {
  @ObjectLink viewModel: HomeViewModel;
  controller?: CustomDialogController;

  aboutToDisappear(): void { this.viewModel.clearLoginDraft(); }

  private close(): void {
    this.viewModel.clearLoginDraft();
    this.controller?.close();
  }

  private async submit(): Promise<void> {
    await this.viewModel.signIn();
    if (this.viewModel.session) this.close();
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Scroll() {
        Column() {
          Text('欢迎回来')
            .fontSize(27)
            .fontWeight(FontWeight.Bold)
            .fontColor(ReaderTheme.INK)
          Text('登录，把喜欢的好书留在身边。')
            .fontSize(13)
            .fontColor(ReaderTheme.MUTED)
            .margin({ top: 9, bottom: 28 })
          Column({ space: 9 }) {
            Text('邮箱').fontSize(13).fontColor(ReaderTheme.SECONDARY)
            TextInput({ placeholder: 'reader@example.com', text: this.viewModel.email })
              .type(InputType.Email)
              .fontSize(14)
              .height(48)
              .borderRadius(11)
              .border({ width: 1, color: ReaderTheme.INPUT_BORDER })
              .backgroundColor(ReaderTheme.SURFACE)
              .fontColor(ReaderTheme.INK)
              .placeholderColor(ReaderTheme.MUTED)
              .enabled(!this.viewModel.busy)
              .onChange((value: string) => { this.viewModel.email = value; })
            Text('密码').fontSize(13).fontColor(ReaderTheme.SECONDARY).margin({ top: 11 })
            TextInput({ placeholder: '请输入密码', text: this.viewModel.password })
              .type(InputType.Password)
              .fontSize(14)
              .height(48)
              .borderRadius(11)
              .border({ width: 1, color: ReaderTheme.INPUT_BORDER })
              .backgroundColor(ReaderTheme.SURFACE)
              .fontColor(ReaderTheme.INK)
              .placeholderColor(ReaderTheme.MUTED)
              .enabled(!this.viewModel.busy)
              .onChange((value: string) => { this.viewModel.password = value; })
              .onSubmit(() => { this.submit(); })
            Text('登录后可搜索图书并获取个人推荐。')
              .fontSize(12)
              .fontColor(ReaderTheme.MUTED)
              .lineHeight(20)
              .margin({ top: 3 })
            if (this.viewModel.loginMessage.length > 0) {
              Text(this.viewModel.loginMessage).fontSize(13).fontColor(ReaderTheme.BLUE).lineHeight(21)
            }
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          Button(this.viewModel.busy ? '登录中' : '登录', { type: ButtonType.Normal })
            .fontSize(15)
            .height(48)
            .width('100%')
            .backgroundColor(ReaderTheme.BLUE)
            .fontColor(ReaderTheme.ON_ACCENT)
            .borderRadius(11)
            .enabled(!this.viewModel.busy)
            .margin({ top: 22 })
            .onClick(() => { this.submit(); })
          Text('凭证通过 HTTPS 发送至书源；会话由系统安全存储保护，账户密码不保存。')
            .fontSize(12)
            .fontColor(ReaderTheme.MUTED)
            .lineHeight(20)
            .textAlign(TextAlign.Center)
            .margin({ top: 23 })
        }
        .width('100%')
        .padding({ top: 36, left: 36, right: 36, bottom: 28 })
      }
      .width('100%')
      .scrollBar(BarState.Auto)
      .constraintSize({ maxHeight: '85%' })
      Button({ type: ButtonType.Normal }) {
        ReaderIcon({ name: 'close', iconSize: 18 })
      }
      .width(34)
      .height(34)
      .backgroundColor(Color.Transparent)
      .borderRadius(9)
      .margin({ top: 12, right: 12 })
      .accessibilityText('关闭登录弹窗')
      .onClick(() => this.close())
    }
    .width('90%')
    .constraintSize({ maxWidth: 420 })
    .backgroundColor(ReaderTheme.SURFACE)
    .borderRadius(25)
    .clip(true)
  }
}
