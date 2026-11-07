import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME: string = 'favor_book';
const KEY_PERSONS: string = 'persons_json';
const KEY_RECORDS: string = 'records_json';

/**
 * Preferences 是鸿蒙轻量键值存储，适合单机个人数据。
 * 这一层只负责读写原始 JSON，不感知业务模型。
 */
export class FavorPreferences {
  private static context: common.Context | null = null;
  private static store: preferences.Preferences | null = null;

  static init(context: common.Context): void {
    FavorPreferences.context = context;
    FavorPreferences.store = null;
  }

  private static async getStore(): Promise<preferences.Preferences> {
    if (FavorPreferences.store !== null) {
      return FavorPreferences.store;
    }
    if (FavorPreferences.context === null) {
      throw new Error('数据存储尚未初始化');
    }
    const store = await preferences.getPreferences(FavorPreferences.context, { name: STORE_NAME });
    FavorPreferences.store = store;
    return store;
  }

  static async readPersons(): Promise<string> {
    const store = await FavorPreferences.getStore();
    const value = await store.get(KEY_PERSONS, '[]');
    return value.toString();
  }

  static async readRecords(): Promise<string> {
    const store = await FavorPreferences.getStore();
    const value = await store.get(KEY_RECORDS, '[]');
    return value.toString();
  }

  static async write(personsJson: string, recordsJson: string): Promise<void> {
    const store = await FavorPreferences.getStore();
    await store.put(KEY_PERSONS, personsJson);
    await store.put(KEY_RECORDS, recordsJson);
    await store.flush();
  }
}
