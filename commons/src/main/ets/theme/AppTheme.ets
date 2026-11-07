/**
 * 视觉基线：颜色、圆角、间距集中在这里，四个功能模块共享同一套设计语言。
 * 颜色语义：收礼（received）用朱红，送礼（given）用墨绿，提醒用暖黄。
 */
export class AppTheme {
  static readonly background: string = '#F5F6FA';
  static readonly card: string = '#FFFFFF';
  static readonly primary: string = '#B23A2F';
  static readonly primaryDark: string = '#8C2A22';
  static readonly primarySoft: string = '#FBEAE7';
  static readonly received: string = '#C0453A';
  static readonly receivedSoft: string = '#FBEAE7';
  static readonly given: string = '#2F7A5B';
  static readonly givenSoft: string = '#E8F3EE';
  static readonly warning: string = '#B7791F';
  static readonly warningSoft: string = '#FCF3DE';
  static readonly textPrimary: string = '#1F2329';
  static readonly textSecondary: string = '#5C6470';
  static readonly textMuted: string = '#9AA1AC';
  static readonly divider: string = '#EDEFF3';
  static readonly track: string = '#EEF0F4';

  static readonly radiusCard: number = 16;
  static readonly radiusSmall: number = 10;
  static readonly pagePadding: number = 16;

  static netColor(net: number): string {
    if (net > 0) {
      return AppTheme.received;
    }
    if (net < 0) {
      return AppTheme.given;
    }
    return AppTheme.textMuted;
  }

  static netBackground(net: number): string {
    if (net > 0) {
      return AppTheme.receivedSoft;
    }
    if (net < 0) {
      return AppTheme.givenSoft;
    }
    return AppTheme.track;
  }

  static netStatus(net: number): string {
    if (net > 0) {
      return '待回礼';
    }
    if (net < 0) {
      return '对方欠我';
    }
    return '已两清';
  }
}
