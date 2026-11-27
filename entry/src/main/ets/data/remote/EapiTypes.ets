export interface EapiUser {
  id?: string | number;
  name?: string;
  email?: string;
  avatar?: string;
  downloads_remaining?: number | string;
  downloads_limit?: number | string;
  downloads_today?: number | string;
}
export interface EapiAuthor { name?: string; }
export interface EapiBook {
  id?: string | number;
  hash?: string;
  title?: string;
  name?: string;
  author?: string;
  authors?: string | EapiAuthor[];
  extension?: string;
  description?: string;
  publisher?: string;
  year?: string | number;
  language?: string;
  pages?: string | number;
  edition?: string | number;
  identifier?: string | number;
  isbn?: string | number;
  filesize?: string | number;
  filesizeString?: string;
  cover?: string;
  url?: string;
  href?: string;
}
export interface EapiFile { downloadLink?: string; filename?: string; }
export interface EapiEnvelope {
  success?: number | boolean;
  error?: string;
  user?: EapiUser;
  books?: EapiBook[];
  book?: EapiBook;
  file?: EapiFile;
  downloadLink?: string;
  url?: string;
  link?: string;
}
export interface RpcLoginUser { user_id?: string | number; user_key?: string; }
export interface RpcLoginEnvelope { errors?: Object[]; response?: RpcLoginUser; }

export function readText(value: string | undefined): string { return typeof value === 'string' ? value.trim() : ''; }

export function readBookText(value: string | undefined, stripMarkup: boolean = false): string {
  let text = readText(value);
  // 上游有一次或两次实体转义；只用于公开书目展示，不用于会话、地址或标识符。
  for (let pass = 0; pass < 2; pass++) {
    text = text.replace(/&(#x[0-9a-f]+|#\d+|amp|lt|gt|quot|apos|nbsp);/gi, (match: string, entity: string): string => {
      switch (entity.toLowerCase()) {
        case 'amp': return '&';
        case 'lt': return '<';
        case 'gt': return '>';
        case 'quot': return '"';
        case 'apos': return "'";
        case 'nbsp': return ' ';
      }
      const code = entity.toLowerCase().startsWith('#x') ? parseInt(entity.slice(2), 16) : parseInt(entity.slice(1), 10);
      return code > 0 && code <= 0x10FFFF && !(code >= 0xD800 && code <= 0xDFFF) ? String.fromCodePoint(code) : match;
    });
  }
  if (stripMarkup) {
    // 只移除标签语法与注释；保留比较表达式，正确识别属性引号中的大于号。
    text = text.replace(/<!--[\s\S]*?-->|<!DOCTYPE\s+[^>]*>|<\/?[a-z][a-z0-9:-]*(?:\s+[a-z_:][a-z0-9_.:-]*(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'=<>`]+))?)*\s*\/?>/gi, ' ');
  }
  return text.replace(/\s+/g, ' ').trim();
}
export function readId(value: string | number | undefined): string {
  if (typeof value === 'number') return Number.isSafeInteger(value) && value > 0 ? `${value}` : '';
  return typeof value === 'string' && /^\d+$/.test(value) && !/^0+$/.test(value) ? value : '';
}
export function readCount(value: number | string | undefined): number | undefined {
  const count = typeof value === 'string' && /^\d+$/.test(value.trim()) ? Number(value) : value;
  return typeof count === 'number' && Number.isSafeInteger(count) && count >= 0 ? count : undefined;
}
