import { ReaderTheme } from '../../shared/theme/ReaderTheme';

@Component
export struct HomeMessage {
  @Prop text: string = '';
  @Prop @Watch('scheduleExpiry') expiresAt: number = 0;
  onExpire: (expiresAt: number) => void = () => {};
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
    this.timer = setTimeout(() => {
      this.timer = -1;
      if (this.active && this.expiresAt === expiresAt) this.onExpire(expiresAt);
    }, Math.max(0, expiresAt - Date.now()));
  }

  build() {
    Text(this.text)
      .width('100%')
      .fontSize(13)
      .fontColor(ReaderTheme.BLUE)
      .margin({ bottom: 12 })
  }
}
