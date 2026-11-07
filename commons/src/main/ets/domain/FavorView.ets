import { FavorRecord } from './FavorRecord';
import { Person } from './Person';

/** 列表展示用的人情记录：附带联系人姓名，避免页面反复查表。 */
export class FavorRecordView {
  record: FavorRecord;
  personName: string;

  constructor(record: FavorRecord, personName: string) {
    this.record = record;
    this.personName = personName;
  }
}

/** 某个联系人的收送汇总。net = 收礼 - 送礼。 */
export class PersonBalance {
  person: Person;
  received: number = 0;
  given: number = 0;
  recordCount: number = 0;
  lastDate: string = '';

  constructor(person: Person) {
    this.person = person;
  }

  net(): number {
    return this.received - this.given;
  }
}

/** 月度收送汇总。 */
export class MonthlyBalance {
  key: string;
  label: string;
  received: number = 0;
  given: number = 0;
  count: number = 0;

  constructor(key: string, label: string) {
    this.key = key;
    this.label = label;
  }
}

/** 全局统计结果。 */
export class FavorStatistics {
  received: number = 0;
  given: number = 0;
  recordCount: number = 0;
  personCount: number = 0;

  net(): number {
    return this.received - this.given;
  }
}
