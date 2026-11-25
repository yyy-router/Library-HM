import { Book, BookFormat } from '../../domain/model/Book';
import { FileImporter } from '../../domain/service/FileImporter';

export class DemoFileImporter implements FileImporter {
  private sequence: number = 0;

  async importBook(): Promise<Book | undefined> {
    this.sequence += 1;
    return new Book(`demo-import-${this.sequence}`, `导入示例 ${this.sequence}`,
      '演示导入', BookFormat.EPUB,
      '此条目用于演示导入流程，尚未调用系统文件选择器或读取文件。');
  }
}
