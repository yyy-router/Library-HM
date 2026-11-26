// 仅由文件适配器在完成写入、检查文件存在且非空后创建。
// 远程地址和只有书目元数据的条目不能代表本地文件。
export class LocalBookFile {
  readonly uri: string;
  readonly size: number;

  constructor(uri: string, size: number) {
    this.uri = uri;
    this.size = size;
  }

  isValid(): boolean {
    return ((this.uri.startsWith('file://') && this.uri.length > 7) ||
      (this.uri.startsWith('/') && !this.uri.startsWith('//') && this.uri.length > 1)) &&
      !/[\r\n]/.test(this.uri) && Number.isInteger(this.size) && this.size > 0;
  }
}
