/**
 * 人情簿领域枚举：所有金额、日期、关系、场合的取值都在这里统一定义，
 * 数据层、功能模块和页面只依赖这些稳定枚举，避免各处散落字符串常量。
 */
export enum Relation {
  RELATIVE = 'relative',
  FRIEND = 'friend',
  COLLEAGUE = 'colleague',
  CLASSMATE = 'classmate',
  NEIGHBOR = 'neighbor',
  OTHER = 'other'
}

export enum FavorType {
  /** 我收到对方的礼金，记为正数 */
  RECEIVE = 'receive',
  /** 我送出礼金，记为负数 */
  GIVE = 'give'
}

export enum Occasion {
  WEDDING = 'wedding',
  BABY = 'baby',
  BIRTHDAY = 'birthday',
  HOUSE = 'house',
  FUNERAL = 'funeral',
  FESTIVAL = 'festival',
  VISIT = 'visit',
  OTHER = 'other'
}

export function allRelations(): Relation[] {
  return [
    Relation.RELATIVE,
    Relation.FRIEND,
    Relation.COLLEAGUE,
    Relation.CLASSMATE,
    Relation.NEIGHBOR,
    Relation.OTHER
  ];
}

export function allOccasions(): Occasion[] {
  return [
    Occasion.WEDDING,
    Occasion.BABY,
    Occasion.BIRTHDAY,
    Occasion.HOUSE,
    Occasion.FUNERAL,
    Occasion.FESTIVAL,
    Occasion.VISIT,
    Occasion.OTHER
  ];
}

export function relationLabel(relation: Relation): string {
  switch (relation) {
    case Relation.RELATIVE:
      return '亲戚';
    case Relation.FRIEND:
      return '朋友';
    case Relation.COLLEAGUE:
      return '同事';
    case Relation.CLASSMATE:
      return '同学';
    case Relation.NEIGHBOR:
      return '邻居';
    default:
      return '其他';
  }
}

export function occasionLabel(occasion: Occasion): string {
  switch (occasion) {
    case Occasion.WEDDING:
      return '婚礼';
    case Occasion.BABY:
      return '满月百日';
    case Occasion.BIRTHDAY:
      return '生日';
    case Occasion.HOUSE:
      return '乔迁';
    case Occasion.FUNERAL:
      return '白事';
    case Occasion.FESTIVAL:
      return '节日';
    case Occasion.VISIT:
      return '探病';
    default:
      return '其他';
  }
}

export function favorTypeLabel(type: FavorType): string {
  return type === FavorType.RECEIVE ? '收礼' : '送礼';
}

export function favorTypeShort(type: FavorType): string {
  return type === FavorType.RECEIVE ? '收' : '送';
}
