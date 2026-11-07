import { FavorRecordView, PersonBalance, FavorStatistics } from './FavorView';

/** 首页一次加载所需的数据聚合，避免页面串行调用多个仓库方法。 */
export class FavorDashboard {
  statistics: FavorStatistics = new FavorStatistics();
  recentRecords: FavorRecordView[] = [];
  pendingReturns: PersonBalance[] = [];
  pendingCount: number = 0;
}
