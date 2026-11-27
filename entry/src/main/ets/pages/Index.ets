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
import { ReaderIcon } from '../shared/components/ReaderIcon';
import { ReaderTheme } from '../shared/theme/ReaderTheme';

@Entry
@Component
struct Index {
  @State private activeTab: number = 0;
  @State private readerVisible: boolean = false;
  @State private pageWidth: number = 1000;
  @State private homeViewModel: HomeViewModel = new HomeViewModel(
    appContainer.catalog, appContainer.bookshelf, appContainer.account);
  @State private bookshelfViewModel: BookshelfViewModel = new BookshelfViewModel(
    appContainer.bookshelf, appContainer.importer, appContainer.downloader);
  @State private readerViewModel: ReaderViewModel = new ReaderViewModel(appContainer.bookshelf);
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

  onBackPress(): boolean {
    if (this.readerVisible) {
      this.closeReader();
      return true;
    }
    return false;
  }

  @Builder
  tabItem(index: number, title: string, icon: string) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 5 }) {
        ReaderIcon({ name: icon, active: this.activeTab === index, iconSize: 22 })
        Text(title).fontSize(12)
          .fontWeight(this.activeTab === index ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.activeTab === index ? ReaderTheme.BLUE : ReaderTheme.MUTED)
      }
      .justifyContent(FlexAlign.Center)
      .width(112)
      .height(60)
    }
    .width(112)
    .height(60)
    .borderRadius(14)
    .backgroundColor(this.activeTab === index ? ReaderTheme.BLUE_TINT : ReaderTheme.SURFACE)
    .accessibilityText(title)
    .accessibilityDescription(this.activeTab === index ? '当前页面' : '')
    .onClick(() => {
      this.activeTab = index;
      if (index === 1) this.bookshelfViewModel.load();
    })
  }

  build() {
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
            HomePage({ viewModel: this.homeViewModel, pageWidth: this.pageWidth })
          } else {
            BookshelfPage({ viewModel: this.bookshelfViewModel, pageWidth: this.pageWidth,
              onOpenBook: (book: Book) => { this.openBook(book); } })
          }
        }
        .width('100%')
        .layoutWeight(1)
        Row({ space: 36 }) {
          this.tabItem(0, '首页', 'home')
          this.tabItem(1, '书架', 'shelf')
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .height(78)
        .border({ width: { top: 1 }, color: ReaderTheme.LINE })
        .backgroundColor(ReaderTheme.SURFACE)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ReaderTheme.BACKGROUND)
    .onAreaChange((_oldArea: Area, newArea: Area) => { this.pageWidth = Number(newArea.width); })
  }
}
