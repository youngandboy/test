import { Person } from './Person';
import { FavorRecord } from './FavorRecord';

/** 数据层与页面之间传递的完整快照（导出、示例数据初始化使用）。 */
export class FavorSnapshot {
  persons: Person[] = [];
  records: FavorRecord[] = [];
}
