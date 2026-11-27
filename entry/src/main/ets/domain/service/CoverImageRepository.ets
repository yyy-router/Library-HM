// 返回可直接显示的图像源；封面获取与 API 会话、书籍文件下载相互独立。
export interface CoverImageRepository {
  load(url: string): Promise<string>;
}

export interface ImageSourceEncoder {
  encode(bytes: Uint8Array, mime: string): string;
}
