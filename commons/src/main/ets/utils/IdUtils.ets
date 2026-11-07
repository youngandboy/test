export class IdUtils {
  private static sequence: number = 0;

  /** 生成带前缀的本地唯一 ID，不依赖额外权限或网络。 */
  static next(prefix: string): string {
    IdUtils.sequence = (IdUtils.sequence + 1) % 100000;
    const time = Date.now().toString(36);
    const seq = IdUtils.sequence.toString(36);
    return `${prefix}-${time}-${seq}`;
  }
}
