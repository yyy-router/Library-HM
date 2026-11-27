import { AppError } from '../../core/error/AppError';
import { AccountSession } from '../../domain/model/AccountSession';
import { HttpHeaders } from '../../core/network/HttpTypes';
import { SessionVault } from '../../core/security/SessionVault';

interface SavedSession { origin: string; id: string; key: string; }

// Only service-issued credentials are retained. Passwords and request bodies are never saved.
export class EapiSessionStore {
  private userId: string = '';
  private userKey: string = '';
  private account: AccountSession | undefined = undefined;
  private revision: number = 0;
  private restored: boolean = false;
  private pending: Promise<void> = Promise.resolve();
  private readonly vault: SessionVault;
  private readonly origin: string;

  constructor(vault: SessionVault, origin: string) { this.vault = vault; this.origin = origin; }

  get version(): number { return this.revision; }
  get display(): AccountSession | undefined { return this.account; }

  async restore(): Promise<void> {
    if (this.restored) return;
    await this.pending;
    const version = this.revision;
    const value = await this.vault.read();
    if (version !== this.revision) return;
    this.restored = true;
    if (!value) return;
    let saved: SavedSession;
    try { saved = JSON.parse(value) as SavedSession; } catch { await this.clear(); return; }
    if (!saved || saved.origin !== this.origin || typeof saved.id !== 'string' || !/^\d+$/.test(saved.id) || /^0+$/.test(saved.id) ||
      typeof saved.key !== 'string' || !saved.key || /[\r\n]/.test(saved.key)) {
      await this.clear(); return;
    }
    this.userId = saved.id; this.userKey = saved.key;
    this.account = new AccountSession(saved.id, '读者');
  }

  async set(id: string, key: string, account: AccountSession): Promise<void> {
    if (!id || !key || /[\r\n]/.test(key)) throw new AppError('INVALID_SESSION', '会话数据无效。');
    const version = ++this.revision;
    const saved: SavedSession = { origin: this.origin, id: id, key: key };
    await this.enqueue(() => this.vault.write(JSON.stringify(saved)));
    if (version !== this.revision) throw new AppError('REQUEST_SUPERSEDED', '会话已改变，请重新登录。');
    this.restored = true; this.userId = id; this.userKey = key; this.account = account;
  }
  update(account: AccountSession): void { if (this.userId) this.account = account; }
  async clear(): Promise<void> {
    this.revision++; this.restored = true; this.userId = ''; this.userKey = ''; this.account = undefined;
    await this.enqueue(() => this.vault.clear());
  }

  private enqueue(operation: () => Promise<void>): Promise<void> {
    const next = this.pending.then(operation);
    this.pending = next.catch(() => {});
    return next;
  }

  headers(): HttpHeaders {
    if (!this.userId || !this.userKey) throw new AppError('AUTH_REQUIRED', '请先在首页登录。');
    return { 'remix-userid': this.userId, 'remix-userkey': this.userKey };
  }
}
