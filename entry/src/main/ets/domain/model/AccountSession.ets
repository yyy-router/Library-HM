// 页面只获取账户显示信息。真实会话密钥应留在数据层的安全存储中。
export class AccountSession {
  readonly accountId: string;
  readonly displayName: string;
  readonly email: string;
  readonly remainingDownloads: number | undefined;
  readonly dailyDownloadLimit: number | undefined;
  readonly avatarUrl: string;

  constructor(accountId: string, displayName: string, email: string = '',
    remainingDownloads: number | undefined = undefined, dailyDownloadLimit: number | undefined = undefined,
    avatarUrl: string = '') {
    this.accountId = accountId;
    this.displayName = displayName;
    this.email = email;
    this.remainingDownloads = remainingDownloads;
    this.dailyDownloadLimit = dailyDownloadLimit;
    this.avatarUrl = avatarUrl;
  }
}
