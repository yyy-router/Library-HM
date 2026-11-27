import { appContainer } from '../app/platform/NativeAppContainer';
import { Book } from '../domain/model/Book';
import { BookshelfPage } from '../features/bookshelf/BookshelfPage';
import { BookshelfViewModel } from '../features/bookshelf/BookshelfViewModel';
import { HomePage } from '../features/home/HomePage';
import { HomeViewModel } from '../features/home/HomeViewModel';
import { AccountHeader } from '../features/home/AccountHeader';
import { LoginDialog } from '../features/home/LoginDialog';
import { ReaderPage } from '../features/reader/ReaderPage';
import { ReaderViewModel } from '../features/reader/ReaderViewModel';
import { BookDetailsPage } from '../features/details/BookDetailsPage';
import { BookDetailsViewModel } from '../features/details/BookDetailsViewModel';
import { ReaderIcon } from '../shared/components/ReaderIcon';
import { ReaderTheme } from '../shared/theme/ReaderTheme';

@Entry
@Component
struct Index {
  @State private activeTab: number = 0;
  @State private readerVisible: boolean = false;
  @State private detailsVisible: boolean = false;
  @State private detailsOpening: boolean = false;
  @State private detailsPreparing: boolean = false;
  private detailsOpenVersion: number = 0;
  @State private pageWidth: number = 1000;
  @State private homeViewModel: HomeViewModel = new HomeViewModel(
    appContainer.catalog, appContainer.bookshelf, appContainer.account);
  @State private bookshelfViewModel: BookshelfViewModel = new BookshelfViewModel(
    appContainer.bookshelf, appContainer.importer, appContainer.downloader);
  @State private readerViewModel: ReaderViewModel = new ReaderViewModel(appContainer.bookshelf);
  @State private detailsViewModel: BookDetailsViewModel = new BookDetailsViewModel(
    appContainer.catalog, appContainer.bookshelf);
  private loginController: CustomDialogController = new CustomDialogController({
    builder: LoginDialog({ viewModel: this.homeViewModel }),
    alignment: DialogAlignment.Center,
    customStyle: true,
    autoCancel: true,
    cancel: () => this.homeViewModel.clearLoginDraft()
  });

  aboutToAppear(): void {
    this.homeViewModel.loadSession();
    this.bookshelfViewModel.load();
  }

  aboutToDisappear(): void {
    this.detailsOpenVersion++;
    this.detailsViewModel.close();
    this.loginController.close();
    this.homeViewModel.clearLoginDraft();
  }

  private async openBook(book: Book): Promise<void> {
    if (await this.readerViewModel.open(book)) {
      this.readerVisible = true;
    } else {
      this.bookshelfViewModel.message = this.readerViewModel.message;
    }
  }

  private closeReader(): void {
    this.readerVisible = false;
    this.activeTab = 1;
    this.bookshelfViewModel.load();
  }

  private openDetails(book: Book): void {
    if (!this.detailsOpening) this.prepareDetails(book);
  }

  private async prepareDetails(book: Book): Promise<void> {
    const version = ++this.detailsOpenVersion;
    this.detailsOpening = true;
    this.detailsPreparing = true;
    await this.detailsViewModel.open(book);
    if (version !== this.detailsOpenVersion || !this.detailsOpening) return;
    const coverUrl = this.detailsViewModel.book.source?.coverUrl;
    if (this.detailsViewModel.details && coverUrl && appContainer.covers) {
      try { await appContainer.covers.load(coverUrl); }
      catch { /* 封面失败不阻止已完成的详情展示。 */ }
    }
    if (version !== this.detailsOpenVersion || !this.detailsOpening) return;
    if (this.detailsViewModel.details) {
      // 完整简介、出版信息和收藏查询均已结束后才创建详情页。
      this.detailsVisible = true;
      this.detailsOpening = false;
    }
    this.detailsPreparing = false;
  }

  private closeDetails(): void {
    this.detailsOpenVersion++;
    const requiresLogin = this.detailsViewModel.requiresLogin;
    this.detailsViewModel.close();
    this.detailsVisible = false;
    this.detailsOpening = false;
    this.detailsPreparing = false;
    if (requiresLogin) this.homeViewModel.handleAuthenticationRequired();
  }

  private showShelfFromDetails(): void {
    this.closeDetails();
    this.activeTab = 1;
    this.bookshelfViewModel.load();
  }

  private loginFromDetails(): void {
    this.closeDetails();
    this.activeTab = 0;
    this.loginController.open();
  }

  onBackPress(): boolean {
    if (this.detailsOpening) {
      this.closeDetails();
      return true;
    }
    if (this.detailsVisible) {
      this.closeDetails();
      return true;
    }
    if (this.readerVisible) {
      this.closeReader();
      return true;
    }
    return false;
  }

  @Builder
  detailsLoadingOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      // 退场动画会暂时保留此节点；结束等待不能等同于请求失败。
      if (this.detailsPreparing || !this.detailsViewModel.hasLoadError) {
        LoadingProgress().width(36).height(36).color(ReaderTheme.BLUE)
          .accessibilityText('正在加载')
      } else {
        Column({ space: 18 }) {
          Text(this.detailsViewModel.message)
            .fontSize(14).lineHeight(24).fontColor(ReaderTheme.INK).textAlign(TextAlign.Center)
          Row({ space: 12 }) {
            Button('取消', { type: ButtonType.Normal })
              .fontSize(14).height(40).fontColor(ReaderTheme.SECONDARY)
              .backgroundColor(ReaderTheme.SUBTLE).borderRadius(10)
              .onClick(() => this.closeDetails())
            Button(this.detailsViewModel.requiresLogin ? '前往登录' : '重试', { type: ButtonType.Normal })
              .fontSize(14).height(40).fontColor(ReaderTheme.ON_ACCENT)
              .backgroundColor(ReaderTheme.BLUE).borderRadius(10)
              .onClick(() => {
                if (this.detailsViewModel.requiresLogin) this.loginFromDetails();
                else this.prepareDetails(this.detailsViewModel.book);
              })
          }
        }
        .padding(28)
        .width('80%')
        .constraintSize({ maxWidth: 340 })
        .backgroundColor(ReaderTheme.SURFACE)
        .borderRadius(20)
        .border({ width: 1, color: ReaderTheme.LINE })
        .shadow({ radius: 20, color: ReaderTheme.SHADOW, offsetY: 6 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ReaderTheme.SHADOW)
    .transition(TransitionEffect.OPACITY.animation({ duration: 120, curve: Curve.EaseOut }))
    .onClick(() => {})
  }

  @Builder
  tabItem(index: number, title: string, icon: string) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 3 }) {
        ReaderIcon({ name: icon, active: this.activeTab === index, iconSize: 22 })
        Text(title).fontSize(11)
          .fontWeight(this.activeTab === index ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.activeTab === index ? ReaderTheme.BLUE : ReaderTheme.MUTED)
      }
      .justifyContent(FlexAlign.Center)
      .width(76)
      .height(46)
    }
    .width(76)
    .height(46)
    .borderRadius(23)
    .backgroundColor(Color.Transparent)
    .accessibilityText(title)
    .accessibilityDescription(this.activeTab === index ? '当前页面' : '')
    .onClick(() => {
      this.activeTab = index;
      if (index === 1) this.bookshelfViewModel.load();
    })
  }

  @Builder
  bottomNavigation() {
    Row({ space: 8 }) {
      this.tabItem(0, '首页', 'home')
      this.tabItem(1, '书架', 'shelf')
    }
    .width(176)
    .height(56)
    .padding({ left: 7, right: 7, top: 4, bottom: 4 })
    .justifyContent(FlexAlign.Center)
    .borderRadius(28)
    .border({ width: 0.5, color: ReaderTheme.LINE })
    .backgroundColor(ReaderTheme.SURFACE)
    .shadow({ radius: 18, color: ReaderTheme.SHADOW, offsetY: 5 })
    .margin({ bottom: 8 })
    .enabled(!this.detailsOpening)
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        if (this.readerVisible) {
          ReaderPage({ viewModel: this.readerViewModel, onBack: () => this.closeReader() })
        } else {
          if (this.activeTab === 0) {
            AccountHeader({ viewModel: this.homeViewModel, pageWidth: this.pageWidth,
              onLogin: () => { this.loginController.open(); } })
          }
          Column() {
            if (this.activeTab === 0) {
              HomePage({ viewModel: this.homeViewModel, pageWidth: this.pageWidth, coverImages: appContainer.covers,
                onOpenDetails: (book: Book) => this.openDetails(book) })
            } else {
              BookshelfPage({ viewModel: this.bookshelfViewModel, pageWidth: this.pageWidth, coverImages: appContainer.covers,
                onOpenBook: (book: Book) => { this.openBook(book); } })
            }
          }
          .width('100%')
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      // 保留列表作为淡入淡出的底层，避免切换时先露出一帧空背景。
      .enabled(!this.detailsOpening && !this.detailsVisible)
      .accessibilityLevel(this.detailsVisible ? 'no-hide-descendants' : 'auto')
      if (!this.readerVisible && !this.detailsVisible) {
        this.bottomNavigation()
      }
      if (this.detailsVisible) {
        BookDetailsPage({ viewModel: this.detailsViewModel, pageWidth: this.pageWidth, coverImages: appContainer.covers,
          onBack: () => this.closeDetails(), onShelf: () => this.showShelfFromDetails() })
          .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut }))
      }
      if (this.detailsOpening) {
        this.detailsLoadingOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ReaderTheme.BACKGROUND)
    .onAreaChange((_oldArea: Area, newArea: Area) => { this.pageWidth = Number(newArea.width); })
  }
}
