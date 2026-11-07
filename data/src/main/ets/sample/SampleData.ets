import { Person, FavorRecord, FavorType, Occasion, Relation, FavorSnapshot, IdUtils, DateUtils } from '@favor/commons';

/** 首次使用时可手动载入的演示数据，覆盖收礼、送礼、待回礼等场景。 */
export class SampleData {
  static create(): FavorSnapshot {
    const snapshot = new FavorSnapshot();
    const zhang = SampleData.person('张阿姨', Relation.RELATIVE, '13800000001', '同小区，常来常往');
    const li = SampleData.person('李哥', Relation.FRIEND, '13800000002', '大学好友，孩子刚满月');
    const wang = SampleData.person('王姐', Relation.COLLEAGUE, '13800000003', '同部门同事');
    const chen = SampleData.person('陈老师', Relation.CLASSMATE, '13800000004', '高中同学');
    const liu = SampleData.person('刘叔', Relation.NEIGHBOR, '13800000005', '楼上邻居，乔迁时帮过忙');
    snapshot.persons = [zhang, li, wang, chen, liu];
    snapshot.records = [
      SampleData.record(zhang.id, FavorType.RECEIVE, 1200, Occasion.WEDDING, DateUtils.offsetMonths(-5, 12), '儿子婚礼'),
      SampleData.record(zhang.id, FavorType.GIVE, 800, Occasion.BIRTHDAY, DateUtils.offsetMonths(-2, 18), '六十大寿'),
      SampleData.record(zhang.id, FavorType.GIVE, 200, Occasion.FESTIVAL, DateUtils.offsetDays(-10), '中秋回礼'),
      SampleData.record(li.id, FavorType.RECEIVE, 600, Occasion.BABY, DateUtils.offsetMonths(-3, 8), '孩子满月'),
      SampleData.record(li.id, FavorType.GIVE, 500, Occasion.HOUSE, DateUtils.offsetMonths(-1, 16), '新房乔迁'),
      SampleData.record(li.id, FavorType.RECEIVE, 200, Occasion.VISIT, DateUtils.offsetDays(-20), '探病慰问'),
      SampleData.record(wang.id, FavorType.RECEIVE, 500, Occasion.FESTIVAL, DateUtils.offsetMonths(-2, 10), '春节走动'),
      SampleData.record(wang.id, FavorType.GIVE, 300, Occasion.BIRTHDAY, DateUtils.offsetMonths(-1, 6), '生日礼物'),
      SampleData.record(chen.id, FavorType.GIVE, 400, Occasion.WEDDING, DateUtils.offsetMonths(-4, 20), '婚礼随礼'),
      SampleData.record(liu.id, FavorType.RECEIVE, 800, Occasion.HOUSE, DateUtils.offsetMonths(-6, 15), '乔迁贺礼')
    ];
    return snapshot;
  }

  private static person(name: string, relation: Relation, phone: string, note: string): Person {
    return {
      id: IdUtils.next('p'),
      name: name,
      relation: relation,
      phone: phone,
      note: note,
      createdAt: Date.now()
    };
  }

  private static record(personId: string, type: FavorType, amount: number, occasion: Occasion, date: string,
    note: string): FavorRecord {
    return {
      id: IdUtils.next('r'),
      personId: personId,
      type: type,
      amount: amount,
      occasion: occasion,
      date: date,
      note: note,
      createdAt: Date.now()
    };
  }
}
