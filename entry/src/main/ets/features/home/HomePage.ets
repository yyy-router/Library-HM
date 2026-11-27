import { Book } from '../../domain/model/Book';
import { CatalogCard } from '../../shared/components/CatalogCard';
import { EmptyState } from '../../shared/components/EmptyState';
import { ReaderIcon } from '../../shared/components/ReaderIcon';
import { ReaderTheme } from '../../shared/theme/ReaderTheme';
import { HomeViewModel, RecommendationState } from './HomeViewModel';

@Component
export struct HomePage {
  @ObjectLink viewModel: HomeViewModel;
  @Prop pageWidth: number = 1000;

  private columns(): number {
    return this.pageWidth > 1100 ? 4 : this.pageWidth > 600 ? 3 : 2;
  }

  private caption(): string {
    if (this.viewModel.searched) return `${this.viewModel.results.length} 本搜索结果`;
    if (!this.viewModel.session) return '看看大家最近在读什么。';
    return '根据你的阅读发现好书。';
  }

  @Builder
  searchBox() {
    Row({ space: 12 }) {
      ReaderIcon({ name: 'search', iconSize: 23 })
      TextInput({ placeholder: '搜索书名、作者，或你感兴趣的内容', text: this.viewModel.keyword })
        .layoutWeight(1)
        .height(50)
        .padding(0)
        .fontSize(this.pageWidth > 600 ? 16 : 13)
        .backgroundColor(ReaderTheme.SURFACE)
        .fontColor(ReaderTheme.INK)
        .placeholderColor(ReaderTheme.MUTED)
        .enterKeyType(EnterKeyType.Search)
        .onChange((value: string) => { this.viewModel.keyword = value; })
        .onSubmit(() => { this.viewModel.search(); })
      Button(this.viewModel.busy ? '处理中' : '搜索图书', { type: ButtonType.Normal })
        .fontSize(this.pageWidth > 600 ? 14 : 12)
        .fontColor(ReaderTheme.ON_ACCENT)
        .height(50)
        .width(this.pageWidth > 600 ? 112 : 80)
        .borderRadius(13)
        .backgroundColor(ReaderTheme.BLUE)
        .enabled(!this.viewModel.busy)
        .onClick(() => { this.viewModel.search(); })
    }
    .padding({ left: 23, right: 10, top: 10, bottom: 10 })
    .width('100%')
    .constraintSize({ maxWidth: 720 })
    .height(72)
    .borderRadius(20)
    .border({ width: 1, color: ReaderTheme.INPUT_BORDER })
    .backgroundColor(ReaderTheme.SURFACE)
    .shadow({ radius: 22, color: ReaderTheme.SHADOW, offsetY: 7 })
  }

  @Builder
  recommendationState() {
    Column({ space: 15 }) {
      if (this.viewModel.recommendationState === RecommendationState.Loading) {
        LoadingProgress().width(28).height(28).color(ReaderTheme.BLUE)
        Text(this.viewModel.session ? '正在获取推荐' : '正在获取热门图书')
          .fontSize(14).fontColor(ReaderTheme.SECONDARY)
      } else {
        Text(this.viewModel.recommendationState === RecommendationState.Unconfigured ? '推荐服务尚未接入' :
          this.viewModel.recommendationState === RecommendationState.Error ? '暂时无法获取图书' :
          this.viewModel.session ? '暂时没有推荐图书' : '暂时没有热门图书')
          .fontSize(20)
          .fontColor(ReaderTheme.INK)
        Text(this.viewModel.recommendationMessage || '可以先搜索书籍，或前往书架继续阅读。')
          .fontSize(14)
          .fontColor(ReaderTheme.SECONDARY)
        if (this.viewModel.recommendationState === RecommendationState.Error ||
          this.viewModel.recommendationState === RecommendationState.Ready) {
          Button('重试').backgroundColor(ReaderTheme.BLUE).fontColor(ReaderTheme.ON_ACCENT)
            .onClick(() => { this.viewModel.loadRecommendations(); })
        }
      }
    }
    .padding({ top: 48, bottom: 44, left: 22, right: 22 })
    .width('100%')
    .borderRadius(20)
    .backgroundColor(ReaderTheme.SURFACE)
    .border({ width: 1, color: ReaderTheme.LINE })
  }

  build() {
    Column() {
      Column() { this.searchBox() }
        .width('100%')
        .padding({ top: this.pageWidth > 600 ? 34 : 20, bottom: 38 })
      Row() {
        Column({ space: 7 }) {
          Text(this.viewModel.searched ? '搜索结果' : this.viewModel.session ? '为你推荐' : '热门图书')
            .fontSize(23)
            .fontWeight(FontWeight.Bold)
            .fontColor(ReaderTheme.INK)
          Text(this.caption()).fontSize(13).fontColor(ReaderTheme.SECONDARY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        if (this.viewModel.searched) {
          Button(this.viewModel.session ? '返回推荐' : '返回热门', { type: ButtonType.Normal })
            .fontSize(13)
            .fontColor(ReaderTheme.BLUE)
            .backgroundColor(ReaderTheme.SURFACE)
            .onClick(() => this.viewModel.clearSearch())
        }
      }
      .width('100%')
      .margin({ bottom: 22 })
      if (this.viewModel.message.length > 0) {
        Text(this.viewModel.message)
          .width('100%')
          .fontSize(13)
          .fontColor(ReaderTheme.BLUE)
          .margin({ bottom: 12 })
      }
      if ((this.viewModel.searched ? this.viewModel.results : this.viewModel.recommendations).length > 0) {
        WaterFlow() {
          ForEach(this.viewModel.searched ? this.viewModel.results : this.viewModel.recommendations, (book: Book) => {
            FlowItem() {
              CatalogCard({ book: book, actionEnabled: !this.viewModel.busy,
                onSave: (selected: Book) => { this.viewModel.addToShelf(selected); } })
            }
          }, (book: Book) => `${this.viewModel.searched ? 'search' : 'discovery'}:${this.viewModel.listRevision}:${book.id}`)
        }
        .columnsTemplate('1fr '.repeat(this.columns()).trim())
        .columnsGap(this.pageWidth > 600 ? 22 : 14)
        .rowsGap(22)
        .cachedCount(4)
        .scrollBar(BarState.Auto)
        .width('100%')
        .layoutWeight(1)
      } else {
        Scroll() {
          Column() {
            if (this.viewModel.searched) {
              EmptyState({ title: '暂无搜索结果', description: '换个书名或作者试试。' })
            } else {
              this.recommendationState()
            }
          }
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: 1280 })
    .padding({ left: this.pageWidth > 840 ? 48 : 24, right: this.pageWidth > 840 ? 48 : 24, bottom: 16 })
  }
}
