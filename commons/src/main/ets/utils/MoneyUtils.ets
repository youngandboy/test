export class MoneyUtils {
  /** 以人民币符号展示两位小数，并添加千分位。 */
  static format(amount: number): string {
    if (!Number.isFinite(amount)) {
      return '¥0.00';
    }
    const negative = amount < 0;
    const fixed = Math.abs(amount).toFixed(2);
    const parts = fixed.split('.');
    const integer = parts[0];
    let grouped = '';
    let counter = 0;
    for (let index = integer.length - 1; index >= 0; index--) {
      grouped = integer.substring(index, index + 1) + grouped;
      counter += 1;
      if (counter % 3 === 0 && index > 0) {
        grouped = ',' + grouped;
      }
    }
    return `${negative ? '-' : ''}¥${grouped}.${parts[1]}`;
  }

  /** 去掉符号的金额，供“待回礼”等场景使用。 */
  static formatAbs(amount: number): string {
    return MoneyUtils.format(Math.abs(amount));
  }

  static parse(text: string): number {
    const value = Number(text.trim());
    if (!Number.isFinite(value)) {
      return 0;
    }
    return Math.round(value * 100) / 100;
  }
}
