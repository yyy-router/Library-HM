import { Book } from '../../domain/model/Book';
import { BookItem } from '../../shared/components/BookItem';
import { EmptyState } from '../../shared/components/EmptyState';
import { HomeViewModel } from './HomeViewModel';

@Component
export struct HomePage {
  @ObjectLink viewModel: HomeViewModel;

  build() {
    Scroll() {
      Column({ space: 20 }) {
        Text('发现下一本想读的书')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        GridRow({ columns: { xs: 1, sm: 1, md: 2, lg: 2 }, gutter: 16 }) {
          GridCol() {
            Column({ space: 14 }) {
              Text('搜索书籍')
                .fontSize(20)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              TextInput({ placeholder: '输入书名、作者，或留空查看演示书籍', text: this.viewModel.keyword })
                .onChange((value: string) => { this.viewModel.keyword = value; })
                .enabled(!this.viewModel.busy)
              Button(this.viewModel.busy ? '处理中' : '搜索')
                .width('100%')
                .backgroundColor($r('app.color.brand_primary'))
                .enabled(!this.viewModel.busy)
                .onClick(() => { this.viewModel.search(); })
              Text('当前搜索使用本地演示数据。')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(20)
            .backgroundColor($r('app.color.surface'))
            .borderRadius(12)
          }
          GridCol() {
            Column({ space: 12 }) {
              Text('账号登录')
                .fontSize(20)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              if (this.viewModel.session) {
                Text(this.viewModel.session?.displayName || '')
                  .fontColor($r('app.color.text_primary'))
                Button('退出登录')
                  .enabled(!this.viewModel.busy)
                  .onClick(() => { this.viewModel.signOut(); })
              } else {
                TextInput({ placeholder: '邮箱（登录占位）', text: this.viewModel.email })
                  .type(InputType.Email)
                  .enabled(!this.viewModel.busy)
                  .onChange((value: string) => { this.viewModel.email = value; })
                TextInput({ placeholder: '密码（登录占位）', text: this.viewModel.password })
                  .type(InputType.Password)
                  .enabled(!this.viewModel.busy)
                  .onChange((value: string) => { this.viewModel.password = value; })
                Button('登录')
                  .width('100%')
                  .enabled(!this.viewModel.busy)
                  .backgroundColor($r('app.color.brand_primary'))
                  .onClick(() => { this.viewModel.signIn(); })
                Text('此处为登录入口占位，尚不发送账号请求。')
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
              }
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(20)
            .backgroundColor($r('app.color.surface'))
            .borderRadius(12)
          }
        }
        if (this.viewModel.message.length > 0) {
          Text(this.viewModel.message)
            .fontSize(14)
            .fontColor($r('app.color.brand_primary'))
            .width('100%')
        }
        if (!this.viewModel.searched) {
          EmptyState({ title: '开始搜索', description: '搜索结果可以加入书架，再打开阅读器占位页。' })
        } else if (this.viewModel.results.length === 0) {
          EmptyState({ title: '暂无搜索结果', description: '试试“阅读”“PDF”或“EPUB”。' })
        } else {
          ForEach(this.viewModel.results, (book: Book) => {
            BookItem({
              book: book,
              actionText: '加入书架',
              actionEnabled: !this.viewModel.busy,
              onAction: (selected: Book) => { this.viewModel.addToShelf(selected); }
            })
          }, (book: Book) => book.id)
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: 1100 })
      .alignItems(HorizontalAlign.Start)
      .padding(24)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
  }
}
