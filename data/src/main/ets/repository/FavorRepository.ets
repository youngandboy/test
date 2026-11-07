import { common } from '@kit.AbilityKit';
import { Person, FavorRecord, FavorRecordView, PersonBalance, FavorDashboard, FavorAnalytics } from '@favor/commons';
import { FavorPreferences } from '../storage/FavorPreferences';
import { SampleData } from '../sample/SampleData';

/**
 * 单例仓库：页面只依赖这一层，不直接接触 Preferences 或 JSON。
 * 内存缓存 + 显式持久化，保证切换 Tab 时不需要重复解析。
 */
export class FavorRepository {
  private static instance: FavorRepository = new FavorRepository();
  private persons: Person[] = [];
  private records: FavorRecord[] = [];
  private loaded: boolean = false;
  private loading: Promise<void> | null = null;

  static getInstance(): FavorRepository {
    return FavorRepository.instance;
  }

  init(context: common.Context): void {
    FavorPreferences.init(context);
  }

  private async ensureLoaded(): Promise<void> {
    if (this.loaded) {
      return;
    }
    if (this.loading === null) {
      this.loading = this.loadFromStorage();
    }
    try {
      await this.loading;
    } catch (error) {
      this.loading = null;
      throw error instanceof Error ? error : new Error(String(error));
    }
  }

  private async loadFromStorage(): Promise<void> {
    const personsJson = await FavorPreferences.readPersons();
    const recordsJson = await FavorPreferences.readRecords();
    this.persons = this.parsePersons(personsJson);
    this.records = this.parseRecords(recordsJson);
    this.loaded = true;
    this.loading = null;
  }

  private parsePersons(json: string): Person[] {
    try {
      return JSON.parse(json) as Person[];
    } catch (error) {
      return [];
    }
  }

  private parseRecords(json: string): FavorRecord[] {
    try {
      return JSON.parse(json) as FavorRecord[];
    } catch (error) {
      return [];
    }
  }

  private async persist(): Promise<void> {
    await FavorPreferences.write(JSON.stringify(this.persons), JSON.stringify(this.records));
  }

  async getPersons(): Promise<Person[]> {
    await this.ensureLoaded();
    return this.persons.slice();
  }

  async getPerson(id: string): Promise<Person | null> {
    await this.ensureLoaded();
    const person = this.persons.find((item: Person): boolean => item.id === id);
    return person === undefined ? null : person;
  }

  async getRecords(): Promise<FavorRecord[]> {
    await this.ensureLoaded();
    return this.records.slice();
  }

  async getRecordViews(): Promise<FavorRecordView[]> {
    await this.ensureLoaded();
    return FavorAnalytics.recordViews(this.persons, this.records);
  }

  async getPersonBalances(): Promise<PersonBalance[]> {
    await this.ensureLoaded();
    return FavorAnalytics.personBalances(this.persons, this.records);
  }

  async getDashboard(): Promise<FavorDashboard> {
    await this.ensureLoaded();
    const dashboard = new FavorDashboard();
    dashboard.statistics = FavorAnalytics.statistics(this.records, this.persons.length);
    dashboard.recentRecords = FavorAnalytics.recordViews(this.persons, this.records).slice(0, 5);
    const balances = FavorAnalytics.personBalances(this.persons, this.records);
    const pending = FavorAnalytics.pendingReturns(balances);
    dashboard.pendingReturns = pending.slice(0, 4);
    dashboard.pendingCount = pending.length;
    return dashboard;
  }

  async savePerson(person: Person): Promise<void> {
    await this.ensureLoaded();
    const index = this.persons.findIndex((item: Person): boolean => item.id === person.id);
    if (index >= 0) {
      this.persons.splice(index, 1, person);
    } else {
      this.persons.push(person);
    }
    await this.persist();
  }

  async deletePerson(id: string): Promise<void> {
    await this.ensureLoaded();
    this.persons = this.persons.filter((item: Person): boolean => item.id !== id);
    this.records = this.records.filter((item: FavorRecord): boolean => item.personId !== id);
    await this.persist();
  }

  async saveRecord(record: FavorRecord): Promise<void> {
    await this.ensureLoaded();
    const exists = this.persons.some((item: Person): boolean => item.id === record.personId);
    if (!exists) {
      throw new Error('联系人不存在，无法保存记录');
    }
    const index = this.records.findIndex((item: FavorRecord): boolean => item.id === record.id);
    if (index >= 0) {
      this.records.splice(index, 1, record);
    } else {
      this.records.push(record);
    }
    await this.persist();
  }

  async deleteRecord(id: string): Promise<void> {
    await this.ensureLoaded();
    this.records = this.records.filter((item: FavorRecord): boolean => item.id !== id);
    await this.persist();
  }

  /** 演示数据只在完全空白时允许载入，避免覆盖真实记录。 */
  async loadSampleData(): Promise<boolean> {
    await this.ensureLoaded();
    if (this.persons.length > 0 || this.records.length > 0) {
      return false;
    }
    const sample = SampleData.create();
    this.persons = sample.persons;
    this.records = sample.records;
    await this.persist();
    return true;
  }

  async clearAll(): Promise<void> {
    await this.ensureLoaded();
    this.persons = [];
    this.records = [];
    await this.persist();
  }
}
