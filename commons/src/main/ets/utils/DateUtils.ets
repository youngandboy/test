/** 日期统一使用 YYYY-MM-DD 字符串，便于排序与本地持久化。 */
export class DateUtils {
  static pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  static formatDate(date: Date): string {
    return `${date.getFullYear()}-${DateUtils.pad(date.getMonth() + 1)}-${DateUtils.pad(date.getDate())}`;
  }

  static today(): string {
    return DateUtils.formatDate(new Date());
  }

  static monthKey(date: string): string {
    return date.length >= 7 ? date.substring(0, 7) : '';
  }

  static monthLabel(key: string): string {
    if (key.length < 7) {
      return key;
    }
    return `${Number(key.substring(5, 7))}月`;
  }

  /** 返回包含本月在内的连续 monthCount 个月份 key，按时间正序。 */
  static lastMonthKeys(monthCount: number): string[] {
    const keys: string[] = [];
    const now = new Date();
    for (let index = monthCount - 1; index >= 0; index--) {
      const monthDate = new Date(now.getFullYear(), now.getMonth() - index, 1);
      keys.push(`${monthDate.getFullYear()}-${DateUtils.pad(monthDate.getMonth() + 1)}`);
    }
    return keys;
  }

  static isValidDate(value: string): boolean {
    const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
    if (match === null) {
      return false;
    }
    const year = Number(match[1]);
    const month = Number(match[2]);
    const day = Number(match[3]);
    const parsed = new Date(year, month - 1, day);
    return parsed.getFullYear() === year && parsed.getMonth() === month - 1 && parsed.getDate() === day;
  }

  static offsetDays(days: number): string {
    const date = new Date();
    date.setDate(date.getDate() + days);
    return DateUtils.formatDate(date);
  }

  static offsetMonths(months: number, day: number): string {
    const now = new Date();
    const date = new Date(now.getFullYear(), now.getMonth() + months, day);
    return DateUtils.formatDate(date);
  }
}
