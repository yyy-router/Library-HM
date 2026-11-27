import { ReaderTheme } from '../theme/ReaderTheme';

@Component
export struct StatusMessage {
  @Prop text: string = '';
  @Prop @Watch('scheduleExpiry') expiresAt: number = 0;
  @Prop @Watch('scheduleExpiry') messageRevision: number = 0;
  @Prop textLineHeight: number = 0;
  onExpire: (expiresAt: number, messageRevision: number) => void = () => {};
  private timer: number = -1;
  private active: boolean = false;

  aboutToAppear(): void { this.active = true; this.scheduleExpiry(); }
  aboutToDisappear(): void { this.active = false; this.cancelTimer(); }

  private cancelTimer(): void {
    if (this.timer !== -1) clearTimeout(this.timer);
    this.timer = -1;
  }

  private scheduleExpiry(): void {
    this.cancelTimer();
    if (!this.active || this.expiresAt <= 0) return;
    const expiresAt = this.expiresAt;
    const revision = this.messageRevision;
    this.timer = setTimeout(() => {
      this.timer = -1;
      if (this.active && this.expiresAt === expiresAt && this.messageRevision === revision) {
        this.onExpire(expiresAt, revision);
      }
    }, Math.max(0, expiresAt - Date.now()));
  }

  build() {
    if (this.textLineHeight > 0) {
      Text(this.text)
        .width('100%')
        .fontSize(13)
        .lineHeight(this.textLineHeight)
        .fontColor(ReaderTheme.BLUE)
    } else {
      Text(this.text)
        .width('100%')
        .fontSize(13)
        .fontColor(ReaderTheme.BLUE)
    }
  }
}
