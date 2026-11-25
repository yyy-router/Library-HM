// 页面只获取账户显示信息。真实会话密钥应留在数据层的安全存储中。
export class AccountSession {
  readonly accountId: string;
  readonly displayName: string;

  constructor(accountId: string, displayName: string) {
    this.accountId = accountId;
    this.displayName = displayName;
  }
}
