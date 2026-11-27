import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppError } from '../../core/error/AppError';
import { SessionVault } from '../../core/security/SessionVault';

export class AssetSessionVault implements SessionVault {
  private readonly alias: Uint8Array = new util.TextEncoder().encodeInto('libraryhm.session.v1');

  async read(): Promise<string | undefined> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.alias);
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const results = await asset.query(query);
      if (results.length === 0) return undefined;
      const value = results[0].get(asset.Tag.SECRET);
      if (!(value instanceof Uint8Array)) throw new AppError('SESSION_STORAGE', '安全会话数据无效。');
      return util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(value);
    } catch (error) {
      if ((error as BusinessError)?.code === 24000002) return undefined;
      throw new AppError('SESSION_STORAGE', '无法读取系统安全会话，请解锁设备后重试。');
    }
  }

  async write(value: string): Promise<void> {
    const bytes = new util.TextEncoder().encodeInto(value);
    if (bytes.byteLength > 1024) throw new AppError('SESSION_STORAGE', '会话数据超出安全存储限制。');
    const attributes: asset.AssetMap = new Map();
    attributes.set(asset.Tag.ALIAS, this.alias);
    attributes.set(asset.Tag.SECRET, bytes);
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED);
    try {
      await asset.add(attributes);
    } catch (error) {
      if ((error as BusinessError)?.code !== 24000003) throw new AppError('SESSION_STORAGE', '安全会话保存失败。');
      const query: asset.AssetMap = new Map(); query.set(asset.Tag.ALIAS, this.alias);
      const updates: asset.AssetMap = new Map(); updates.set(asset.Tag.SECRET, bytes);
      try { await asset.update(query, updates); }
      catch { throw new AppError('SESSION_STORAGE', '安全会话更新失败。'); }
    }
  }

  async clear(): Promise<void> {
    const query: asset.AssetMap = new Map(); query.set(asset.Tag.ALIAS, this.alias);
    try { await asset.remove(query); }
    catch (error) {
      if ((error as BusinessError)?.code !== 24000002) throw new AppError('SESSION_STORAGE', '安全会话删除失败，请重试。');
    }
  }
}
