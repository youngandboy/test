import { Person } from './Person';
import { FavorRecord } from './FavorRecord';
import { FavorType } from './FavorTypes';
import { FavorRecordView, PersonBalance, MonthlyBalance, FavorStatistics } from './FavorView';
import { DateUtils } from '../utils/DateUtils';

/**
 * 纯函数统计层：不依赖 UI、不依赖存储，便于单元测试。
 * 页面拿到的所有汇总数字都来自这里，保证首页、统计页口径一致。
 */
export class FavorAnalytics {
  static statistics(records: FavorRecord[], personCount: number = 0): FavorStatistics {
    const result = new FavorStatistics();
    result.personCount = personCount;
    records.forEach((record: FavorRecord) => {
      result.recordCount += 1;
      if (record.type === FavorType.RECEIVE) {
        result.received += record.amount;
      } else {
        result.given += record.amount;
      }
    });
    return result;
  }

  static recordViews(persons: Person[], records: FavorRecord[]): FavorRecordView[] {
    const personMap = new Map<string, Person>();
    persons.forEach((person: Person) => {
      personMap.set(person.id, person);
    });
    const views: FavorRecordView[] = [];
    records.forEach((record: FavorRecord) => {
      const person = personMap.get(record.personId);
      const name: string = person === undefined ? '未知联系人' : person.name;
      views.push(new FavorRecordView(record, name));
    });
    views.sort((left: FavorRecordView, right: FavorRecordView): number => {
      if (left.record.date === right.record.date) {
        return right.record.createdAt - left.record.createdAt;
      }
      return left.record.date < right.record.date ? 1 : -1;
    });
    return views;
  }

  static personBalances(persons: Person[], records: FavorRecord[]): PersonBalance[] {
    const balanceMap = new Map<string, PersonBalance>();
    persons.forEach((person: Person) => {
      balanceMap.set(person.id, new PersonBalance(person));
    });
    records.forEach((record: FavorRecord) => {
      const balance = balanceMap.get(record.personId);
      if (balance === undefined) {
        return;
      }
      balance.recordCount += 1;
      if (record.type === FavorType.RECEIVE) {
        balance.received += record.amount;
      } else {
        balance.given += record.amount;
      }
      if (record.date > balance.lastDate) {
        balance.lastDate = record.date;
      }
    });
    const result: PersonBalance[] = [];
    balanceMap.forEach((value: PersonBalance) => {
      result.push(value);
    });
    result.sort((left: PersonBalance, right: PersonBalance): number => {
      const difference = Math.abs(right.net()) - Math.abs(left.net());
      if (difference !== 0) {
        return difference;
      }
      if (left.person.name === right.person.name) {
        return 0;
      }
      return left.person.name < right.person.name ? -1 : 1;
    });
    return result;
  }

  static monthly(records: FavorRecord[], monthCount: number): MonthlyBalance[] {
    const keys: string[] = DateUtils.lastMonthKeys(monthCount);
    const bucketMap = new Map<string, MonthlyBalance>();
    keys.forEach((key: string) => {
      bucketMap.set(key, new MonthlyBalance(key, DateUtils.monthLabel(key)));
    });
    records.forEach((record: FavorRecord) => {
      const bucket = bucketMap.get(DateUtils.monthKey(record.date));
      if (bucket === undefined) {
        return;
      }
      bucket.count += 1;
      if (record.type === FavorType.RECEIVE) {
        bucket.received += record.amount;
      } else {
        bucket.given += record.amount;
      }
    });
    return keys.map((key: string): MonthlyBalance => {
      const bucket = bucketMap.get(key);
      if (bucket === undefined) {
        return new MonthlyBalance(key, DateUtils.monthLabel(key));
      }
      return bucket;
    });
  }

  static pendingReturns(balances: PersonBalance[]): PersonBalance[] {
    const pending: PersonBalance[] = balances.filter((item: PersonBalance): boolean => item.net() > 0);
    pending.sort((left: PersonBalance, right: PersonBalance): number => right.net() - left.net());
    return pending;
  }
}
