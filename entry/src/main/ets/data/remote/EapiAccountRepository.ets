import { AppError } from '../../core/error/AppError';
import { HttpParameter } from '../../core/network/HttpTypes';
import { AccountSession } from '../../domain/model/AccountSession';
import { AccountRepository } from '../../domain/repository/AccountRepository';
import { EapiClient } from './EapiClient';
import { readCount, readId, readText, RpcLoginEnvelope } from './EapiTypes';

export class EapiAccountRepository implements AccountRepository {
  private readonly api: EapiClient;
  constructor(api: EapiClient) { this.api = api; }

  async getSession(): Promise<AccountSession | undefined> {
    await this.api.sessions.restore();
    const current = this.api.sessions.display;
    if (!current) return undefined;
    const result = await this.api.get('/eapi/user/profile');
    const user = result.user;
    if (!user || typeof user !== 'object' || readId(user.id) !== current.accountId) {
      throw new AppError('INVALID_RESPONSE', '账户信息缺失或与当前会话不一致。');
    }
    const limit = readCount(user.downloads_limit);
    const used = readCount(user.downloads_today);
    const remaining = readCount(user.downloads_remaining) ??
      (limit !== undefined && used !== undefined ? Math.max(0, limit - used) : undefined);
    const account = new AccountSession(current.accountId, readText(user.name) || current.displayName,
      readText(user.email) || current.email, remaining, limit);
    this.api.sessions.update(account);
    return account;
  }

  async signIn(email: string, password: string): Promise<AccountSession> {
    if (!email.trim() || !password) throw new AppError('INVALID_CREDENTIALS', '请填写邮箱和密码。');
    const version = this.api.sessions.version;
    const response = await this.api.http.postForm('/rpc.php', [
      new HttpParameter('isModal', 'true'), new HttpParameter('email', email.trim()),
      new HttpParameter('password', password), new HttpParameter('site_mode', 'books'),
      new HttpParameter('action', 'login'), new HttpParameter('gg_json_mode', '1'),
      new HttpParameter('redirectUrl', `${this.api.http.baseUrl}/`)
    ]);
    const result = response.json<RpcLoginEnvelope>();
    const id = readId(result?.response?.user_id);
    const key = readText(result?.response?.user_key);
    if (!id || !key || (Array.isArray(result.errors) && result.errors.length > 0)) {
      throw new AppError('LOGIN_FAILED', '登录失败，请检查邮箱、密码或书源是否需要额外验证。');
    }
    if (version !== this.api.sessions.version) throw new AppError('REQUEST_SUPERSEDED', '会话已改变，请重新登录。');
    const fallback = new AccountSession(id, email.trim().split('@')[0], email.trim());
    await this.api.sessions.set(id, key, fallback);
    try { return await this.getSession() ?? fallback; }
    catch (error) {
      if (!this.api.sessions.display || this.api.sessions.display.accountId !== id) {
        if (error instanceof AppError) throw error;
        throw new AppError('LOGIN_FAILED', '登录状态无法确认，请重新登录。');
      }
      return this.api.sessions.display;
    }
  }

  async signOut(): Promise<void> { await this.api.sessions.clear(); }
}
