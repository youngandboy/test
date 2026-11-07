import { promptAction } from '@kit.ArkUI';
import { AppTheme, FavorAnalytics, FavorStatistics, MoneyUtils, MonthlyBalance, PersonBalance,
  relationLabel } from '@favor/commons';
import { EmptyState, SectionTitle, StatTile } from '@favor/ui';
import { FavorRepository } from '@favor/data';

/** 统计页：收送总览、收送比例、近六个月趋势和联系人差额排行。 */
@Component
export struct StatisticsPage {
  onAddRecord: () => void = () => {};
  @Prop @Watch('onActiveChanged') active: boolean = true;
  @State stats: FavorStatistics = new FavorStatistics();
  @State balances: PersonBalance[] = [];
  @State monthly: MonthlyBalance[] = [];
  @State loading: boolean = true;
  private repo: FavorRepository = FavorRepository.getInstance();

  aboutToAppear(): void {
    this.reload();
  }

  onActiveChanged(): void {
    if (this.active) {
      this.reload();
    }
  }

  private async reload(): Promise<void> {
    try {
      const records = await this.repo.getRecords();
      const persons = await this.repo.getPersons();
      this.stats = FavorAnalytics.statistics(records, persons.length);
      this.balances = FavorAnalytics.personBalances(persons, records);
      this.monthly = FavorAnalytics.monthly(records, 6);
    } catch (error) {
      // 保持空统计状态。
    }
    this.loading = false;
  }

  private receivedPercent(): number {
    const total = this.stats.received + this.stats.given;
    if (total <= 0) {
      return 50;
    }
    return Math.round(this.stats.received / total * 100);
  }

  private maxMonthlyValue(): number {
    let max = 1;
    this.monthly.forEach((item: MonthlyBalance) => {
      max = Math.max(max, item.received, item.given);
    });
    return max;
  }

  private barHeight(value: number): number {
    const max = this.maxMonthlyValue();
    return Math.max(4, Math.round(value / max * 72));
  }

  private confirmClear(): void {
    AlertDialog.show({
      title: '清空全部数据',
      message: '将删除所有联系人和人情记录，且无法恢复。确定继续吗？',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '清空',
        fontColor: AppTheme.primary,
        action: () => {
          this.clearData();
        }
      }
    });
  }

  private async clearData(): Promise<void> {
    try {
      await this.repo.clearAll();
      await this.reload();
      promptAction.showToast({ message: '数据已清空' });
    } catch (error) {
      promptAction.showToast({ message: '清空失败，请重试' });
    }
  }

  @Builder
  header() {
    Row() {
      Column({ space: 3 }) {
        Text('统计')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.textPrimary)
        Text('看清每一份人情的来与往')
          .fontSize(11)
          .fontColor(AppTheme.textMuted)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('📊')
        .fontSize(26)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 10 })
  }

  @Builder
  legendItem(color: string, label: string) {
    Row({ space: 4 }) {
      Text('●')
        .fontSize(10)
        .fontColor(color)
      Text(label)
        .fontSize(10)
        .fontColor(AppTheme.textMuted)
    }
  }

  @Builder
  rankingRow(item: PersonBalance, index: number) {
    Row({ space: 10 }) {
      Text(`${index + 1}`)
        .width(20)
        .height(20)
        .borderRadius(10)
        .textAlign(TextAlign.Center)
        .fontSize(10)
        .fontColor(index < 3 ? AppTheme.primary : AppTheme.textMuted)
        .backgroundColor(index < 3 ? AppTheme.primarySoft : AppTheme.track)
      Column({ space: 3 }) {
        Text(item.person.name)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
        Text(`${relationLabel(item.person.relation)} · ${item.recordCount} 笔往来`)
          .fontSize(10)
          .fontColor(AppTheme.textMuted)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Column({ space: 3 }) {
        Text(AppTheme.netStatus(item.net()))
          .fontSize(10)
          .fontColor(AppTheme.netColor(item.net()))
        Text(MoneyUtils.formatAbs(item.net()))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.netColor(item.net()))
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppTheme.card)
    .borderRadius(12)
  }

  build() {
    Column() {
      this.header()

      if (this.loading) {
        Row() {
          LoadingProgress()
            .width(32)
            .height(32)
            .color(AppTheme.primary)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.stats.recordCount === 0) {
        Column() {
          EmptyState({
            icon: '📊',
            title: '还没有可统计的数据',
            hint: '记下几笔人情往来后，这里会自动生成收送对比与排行',
            actionText: '去记一笔',
            onAction: (): void => {
              this.onAddRecord();
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            Row({ space: 8 }) {
              StatTile({
                label: '累计收礼',
                value: MoneyUtils.format(this.stats.received),
                color: AppTheme.received
              })
              StatTile({
                label: '累计送礼',
                value: MoneyUtils.format(this.stats.given),
                color: AppTheme.given
              })
              StatTile({
                label: '净额',
                value: MoneyUtils.format(this.stats.net()),
                color: AppTheme.netColor(this.stats.net())
              })
            }
            .width('100%')

            SectionTitle({ title: '收送对比', subtitle: `共 ${this.stats.recordCount} 笔` })
            Column({ space: 10 }) {
              Row() {
                Text(MoneyUtils.format(this.stats.received))
                  .fontSize(12)
                  .fontColor(AppTheme.received)
                Blank()
                Text(MoneyUtils.format(this.stats.given))
                  .fontSize(12)
                  .fontColor(AppTheme.given)
              }
              .width('100%')

              Row() {
                Text('')
                  .width(`${this.receivedPercent()}%`)
                  .height(10)
                  .backgroundColor(AppTheme.received)
                Text('')
                  .width(`${100 - this.receivedPercent()}%`)
                  .height(10)
                  .backgroundColor(AppTheme.given)
              }
              .width('100%')
              .borderRadius(5)
              .clip(true)

              Row({ space: 16 }) {
                this.legendItem(AppTheme.received, '收礼')
                this.legendItem(AppTheme.given, '送礼')
                Blank()
                Text(`净额 ${MoneyUtils.format(this.stats.net())}`)
                  .fontSize(11)
                  .fontColor(AppTheme.netColor(this.stats.net()))
              }
              .width('100%')
            }
            .width('100%')
            .padding(14)
            .backgroundColor(AppTheme.card)
            .borderRadius(14)

            SectionTitle({ title: '近六个月', subtitle: '单位：元' })
            Column({ space: 10 }) {
              Row({ space: 4 }) {
                ForEach(this.monthly, (item: MonthlyBalance) => {
                  Column({ space: 4 }) {
                    Row({ space: 2 }) {
                      Text('')
                        .width(9)
                        .height(this.barHeight(item.received))
                        .backgroundColor(AppTheme.received)
                        .borderRadius(3)
                      Text('')
                        .width(9)
                        .height(this.barHeight(item.given))
                        .backgroundColor(AppTheme.given)
                        .borderRadius(3)
                    }
                    .height(76)
                    .alignItems(VerticalAlign.Bottom)
                    Text(item.label)
                      .fontSize(9)
                      .fontColor(AppTheme.textMuted)
                  }
                  .layoutWeight(1)
                }, (item: MonthlyBalance) => item.key)
              }
              .width('100%')

              Row({ space: 16 }) {
                this.legendItem(AppTheme.received, '收礼')
                this.legendItem(AppTheme.given, '送礼')
              }
              .width('100%')
            }
            .width('100%')
            .padding(14)
            .backgroundColor(AppTheme.card)
            .borderRadius(14)

            SectionTitle({ title: '人情往来排行', subtitle: '按差额' })
            Column({ space: 8 }) {
              ForEach(this.balances.slice(0, 5), (item: PersonBalance, index: number) => {
                this.rankingRow(item, index)
              }, (item: PersonBalance) => item.person.id)
            }
            .width('100%')

            Column({ space: 8 }) {
              Text('所有数据仅保存在本机，卸载应用会一并清除。')
                .fontSize(10)
                .fontColor(AppTheme.textMuted)
              Button('清空全部数据')
                .height(34)
                .fontSize(12)
                .fontColor(AppTheme.primary)
                .backgroundColor(AppTheme.receivedSoft)
                .onClick(() => {
                  this.confirmClear();
                })
            }
            .width('100%')
            .margin({ top: 26, bottom: 28 })
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.background)
  }
}
