import { describe, it, expect } from '@ohos/hypium';
import { FavorAnalytics, FavorRecord, FavorType, MoneyUtils, Occasion, Person, Relation, DateUtils } from '@favor/commons';

const personA: Person = {
  id: 'p-a',
  name: '张阿姨',
  relation: Relation.RELATIVE,
  phone: '',
  note: '',
  createdAt: 1
};

const personB: Person = {
  id: 'p-b',
  name: '李哥',
  relation: Relation.FRIEND,
  phone: '',
  note: '',
  createdAt: 2
};

const records: FavorRecord[] = [
  {
    id: 'r-1',
    personId: 'p-a',
    type: FavorType.RECEIVE,
    amount: 1200,
    occasion: Occasion.WEDDING,
    date: '2026-05-12',
    note: '儿子婚礼',
    createdAt: 1
  },
  {
    id: 'r-2',
    personId: 'p-a',
    type: FavorType.GIVE,
    amount: 800,
    occasion: Occasion.BIRTHDAY,
    date: '2026-09-18',
    note: '六十大寿',
    createdAt: 2
  },
  {
    id: 'r-3',
    personId: 'p-b',
    type: FavorType.GIVE,
    amount: 300,
    occasion: Occasion.HOUSE,
    date: '2026-10-01',
    note: '乔迁',
    createdAt: 3
  }
];

export default function localUnitTest() {
  describe('FavorAnalytics', () => {
    it('calculatesReceivedGivenAndNet', 0, () => {
      const stats = FavorAnalytics.statistics(records, 2);
      expect(stats.received).assertEqual(1200);
      expect(stats.given).assertEqual(1100);
      expect(stats.net()).assertEqual(100);
      expect(stats.recordCount).assertEqual(3);
      expect(stats.personCount).assertEqual(2);
    });

    it('groupsBalancesByPerson', 0, () => {
      const balances = FavorAnalytics.personBalances([personA, personB], records);
      expect(balances.length).assertEqual(2);
      const first = balances[0];
      expect(first.person.id).assertEqual('p-a');
      expect(first.received).assertEqual(1200);
      expect(first.given).assertEqual(800);
      expect(first.net()).assertEqual(400);
      expect(first.recordCount).assertEqual(2);
      expect(first.lastDate).assertEqual('2026-09-18');
    });

    it('returnsPendingReturnsDescending', 0, () => {
      const balances = FavorAnalytics.personBalances([personA, personB], records);
      const pending = FavorAnalytics.pendingReturns(balances);
      expect(pending.length).assertEqual(1);
      expect(pending[0].person.id).assertEqual('p-a');
    });

    it('sortsRecordViewsByDateDescending', 0, () => {
      const views = FavorAnalytics.recordViews([personA, personB], records);
      expect(views.length).assertEqual(3);
      expect(views[0].record.id).assertEqual('r-3');
      expect(views[0].personName).assertEqual('李哥');
    });
  });

  describe('Utils', () => {
    it('formatsMoneyWithThousandsSeparator', 0, () => {
      expect(MoneyUtils.format(1200)).assertEqual('¥1,200.00');
      expect(MoneyUtils.format(0)).assertEqual('¥0.00');
      expect(MoneyUtils.format(-12.5)).assertEqual('-¥12.50');
    });

    it('validatesYmdDate', 0, () => {
      expect(DateUtils.isValidDate('2026-11-07')).assertTrue();
      expect(DateUtils.isValidDate('2026-02-30')).assertFalse();
      expect(DateUtils.isValidDate('2026/11/07')).assertFalse();
    });
  });
}
