import { appContainer } from '../app/AppContainer';
import { AppConfig } from '../core/config/AppConfig';
import { Book } from '../domain/model/Book';
import { BookshelfPage } from '../features/bookshelf/BookshelfPage';
import { BookshelfViewModel } from '../features/bookshelf/BookshelfViewModel';
import { HomePage } from '../features/home/HomePage';
import { HomeViewModel } from '../features/home/HomeViewModel';
import { ReaderPage } from '../features/reader/ReaderPage';
import { ReaderViewModel } from '../features/reader/ReaderViewModel';

@Entry
@Component
struct Index {
  @State private activeTab: number = 0;
  @State private readerVisible: boolean = false;
  @State private homeViewModel: HomeViewModel = new HomeViewModel(
    appContainer.catalog, appContainer.bookshelf, appContainer.account);
  @State private bookshelfViewModel: BookshelfViewModel = new BookshelfViewModel(
    appContainer.bookshelf, appContainer.importer);
  @State private readerViewModel: ReaderViewModel = new ReaderViewModel(appContainer.bookshelf);

  aboutToAppear(): void {
    this.homeViewModel.loadSession();
    this.bookshelfViewModel.load();
  }

  private openBook(book: Book): void {
    this.readerViewModel.open(book);
    this.readerVisible = true;
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

  build() {
    Column() {
      if (this.readerVisible) {
        ReaderPage({ viewModel: this.readerViewModel, onBack: () => this.closeReader() })
      } else {
        Row({ space: 16 }) {
          Text(AppConfig.APP_NAME)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Text('演示模式')
            .fontSize(14)
            .fontColor($r('app.color.brand_primary'))
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor($r('app.color.demo_background'))
            .borderRadius(8)
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 16, bottom: 12 })
        Tabs({ index: this.activeTab, barPosition: BarPosition.End }) {
          TabContent() {
            HomePage({ viewModel: this.homeViewModel })
          }
          .tabBar('首页')
          TabContent() {
            BookshelfPage({
              viewModel: this.bookshelfViewModel,
              onOpenBook: (book: Book) => this.openBook(book)
            })
          }
          .tabBar('书架')
        }
        .barMode(BarMode.Fixed)
        .barHeight(64)
        .width('100%')
        .layoutWeight(1)
        .onChange((index: number) => {
          this.activeTab = index;
          if (index === 1) this.bookshelfViewModel.load();
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
  }
}
