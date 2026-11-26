import { ReaderIcon } from '../../shared/components/ReaderIcon';
import { ReaderTheme } from '../../shared/theme/ReaderTheme';
import { HomeViewModel } from './HomeViewModel';

interface AccountPopupState { isVisible: boolean; }

@Component
export struct AccountHeader {
  @ObjectLink viewModel: HomeViewModel;
  @Prop pageWidth: number = 1000;
  @State private accountVisible: boolean = false;
  onLogin: () => void = () => {};

  private initial(): string { return (this.viewModel.session?.displayName || '读者').slice(0, 1); }
  private quota(): string {
    const count = this.viewModel.session?.remainingDownloads;
    return count === undefined ? '--' : `${count}`;
  }

  private quotaProgress(): number {
    const count = this.viewModel.session?.remainingDownloads;
    const total = this.viewModel.session?.dailyDownloadLimit;
    return count !== undefined && total !== undefined && total > 0 ? Math.min(100, Math.max(0, count / total * 100)) : 0;
  }

  @Builder
  avatar(size: number) {
    if (this.viewModel.session?.avatarUrl) {
      Image(this.viewModel.session?.avatarUrl || '').width(size).height(size).borderRadius(size / 2)
    } else {
      Text(this.initial()).fontSize(size > 40 ? 21 : 14).fontWeight(FontWeight.Medium)
        .fontColor(ReaderTheme.BLUE).textAlign(TextAlign.Center)
        .width(size).height(size).backgroundColor(ReaderTheme.BLUE_TINT).borderRadius(size / 2)
    }
  }

  @Builder
  accountPanel() {
    Column({ space: 20 }) {
      Row({ space: 12 }) {
        this.avatar(49)
        Column({ space: 5 }) {
          Text(this.viewModel.session?.displayName || '读者')
            .fontSize(18).fontWeight(FontWeight.Medium).fontColor(ReaderTheme.INK)
          Text(this.viewModel.session?.email || '')
            .fontSize(12).fontColor(ReaderTheme.MUTED).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      Column({ space: 12 }) {
        Text('今日剩余下载').fontSize(13).fontColor(ReaderTheme.SECONDARY)
        Row({ space: 7 }) {
          Text(this.quota()).fontSize(37).fontWeight(FontWeight.Bold).fontColor(ReaderTheme.BLUE)
          Text(this.viewModel.session?.dailyDownloadLimit === undefined ? '次' :
            `/ ${this.viewModel.session?.dailyDownloadLimit} 次`).fontSize(13).fontColor(ReaderTheme.MUTED)
        }
        .alignItems(VerticalAlign.Bottom)
        Progress({ value: this.quotaProgress(), total: 100, type: ProgressType.Linear })
          .width('100%').color(ReaderTheme.BLUE).backgroundColor(ReaderTheme.TRACK).style({ strokeWidth: 5 })
        if (this.viewModel.session?.remainingDownloads === undefined) {
          Text('额度暂不可用').fontSize(12).fontColor(ReaderTheme.MUTED)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(17)
      .backgroundColor(ReaderTheme.BLUE_TINT)
      .borderRadius(12)
      Button('退出登录', { type: ButtonType.Normal })
        .width('100%').height(40).fontSize(13)
        .fontColor(ReaderTheme.SECONDARY).backgroundColor(ReaderTheme.SURFACE)
        .enabled(!this.viewModel.busy)
        .onClick(() => { this.accountVisible = false; this.viewModel.signOut(); })
    }
    .width(300)
    .padding(23)
    .backgroundColor(ReaderTheme.SURFACE)
  }

  build() {
    Row({ space: 20 }) {
      Blank()
      Text('演示模式').fontSize(12).fontColor(ReaderTheme.MUTED)
      Button({ type: ButtonType.Normal }) {
        Row({ space: 9 }) {
          if (this.viewModel.session) {
            this.avatar(31)
            Text(this.viewModel.session?.displayName || '').fontSize(14).fontColor(ReaderTheme.SECONDARY)
              .maxLines(1).constraintSize({ maxWidth: 110 }).textOverflow({ overflow: TextOverflow.Ellipsis })
            ReaderIcon({ name: 'chevron', iconSize: 15 })
          } else {
            ReaderIcon({ name: 'user', active: true, iconSize: 18 })
            Text('登录').fontSize(14).fontColor(ReaderTheme.SECONDARY)
          }
        }
        .padding({ left: 15, right: 15 })
      }
      .height(40)
      .backgroundColor(ReaderTheme.SURFACE)
      .borderRadius(22)
      .border({ width: this.viewModel.session ? 0 : 1, color: ReaderTheme.INPUT_BORDER })
      .onClick(() => {
        if (this.viewModel.session) this.accountVisible = !this.accountVisible;
        else this.onLogin();
      })
      .bindPopup(this.accountVisible, {
        builder: this.accountPanel,
        placement: Placement.BottomRight,
        enableArrow: false,
        popupColor: ReaderTheme.SURFACE,
        radius: 21,
        onStateChange: (event: AccountPopupState) => { this.accountVisible = event.isVisible; }
      })
    }
    .height(84)
    .width('100%')
    .constraintSize({ maxWidth: 1280 })
    .padding({ left: this.pageWidth > 840 ? 48 : 24, right: this.pageWidth > 840 ? 48 : 24 })
  }
}
