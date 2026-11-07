import { promptAction } from '@kit.ArkUI';
import { AppTheme, FavorDashboard, FavorRecordView, FavorType, MoneyUtils, PersonBalance, occasionLabel,
  relationLabel } from '@favor/commons';
import { Avatar, EmptyState, SectionTitle, Tag } from '@favor/ui';
import { FavorRepository } from '@favor/data';

/**
 * 首页看板：人情余额、快速入口、待回礼提醒和最近往来。
 * 只负责展示与导航，数据统一由 FavorRepository 提供。
 */
@Component
export struct HomePage {
  onGoRecords: () => void = () => {};
  onGoContacts: () => void = () => {};
  onAddRecord: () => void = () => {};
  @Prop @Watch('onActiveChanged') active: boolean = true;
  @State dashboard: FavorDashboard = new FavorDashboard();
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
      this.dashboard = await this.repo.getDashboard();
    } catch (error) {
      // 读取失败时保持空看板，页面仍可继续操作。
    }
    this.loading = false;
  }

  private async loadSample(): Promise<void> {
    try {
      const loaded = await this.repo.loadSampleData();
      if (!loaded) {
        promptAction.showToast({ message: '已有数据，未覆盖现有记录' });
      }
      await this.reload();
    } catch (error) {
      promptAction.showToast({ message: '载入示例数据失败' });
    }
  }

  private netHint(): string {
    const net = this.dashboard.statistics.net();
    if (net > 0) {
      return '人情有来有往，记得把心意还回去';
    }
    if (net < 0) {
      return '你送出的更多，对方还欠着这份心意';
    }
    return '人情往来基本平衡，继续保持';
  }

  @Builder
  header() {
    Row() {
      Column({ space: 2 }) {
        Text('人情簿')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.textPrimary)
        Text('把每一份人情放在心上')
          .fontSize(12)
          .fontColor(AppTheme.textMuted)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('🧧')
        .fontSize(28)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 8 })
  }

  @Builder
  heroCard() {
    Column({ space: 14 }) {
      Row() {
        Text('人情往来余额')
          .fontSize(12)
          .fontColor('#F3D8D4')
        Blank()
        Text(`${this.dashboard.statistics.personCount} 位联系人`)
          .fontSize(11)
          .fontColor('#F3D8D4')
      }
      .width('100%')

      Text(MoneyUtils.format(this.dashboard.statistics.net()))
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)

      Text(this.netHint())
        .fontSize(12)
        .fontColor('#F3D8D4')

      Row({ space: 8 }) {
        this.heroStat('累计收礼', MoneyUtils.format(this.dashboard.statistics.received))
        this.heroStat('累计送礼', MoneyUtils.format(this.dashboard.statistics.given))
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .borderRadius(18)
    .backgroundColor(AppTheme.primary)
  }

  @Builder
  heroStat(label: string, value: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(11)
        .fontColor('#F3D8D4')
      Text(value)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
    }
    .layoutWeight(1)
    .padding(10)
    .backgroundColor('#26FFFFFF')
    .borderRadius(10)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  actionCard(icon: string, title: string, subtitle: string, action: string) {
    Row({ space: 10 }) {
      Text(icon)
        .fontSize(22)
        .width(38)
        .height(38)
        .textAlign(TextAlign.Center)
        .backgroundColor(AppTheme.primarySoft)
        .borderRadius(10)
      Column({ space: 3 }) {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
        Text(subtitle)
          .fontSize(10)
          .fontColor(AppTheme.textMuted)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .padding(12)
    .backgroundColor(AppTheme.card)
    .borderRadius(14)
    .onClick(() => {
      if (action === 'add') {
        this.onAddRecord();
      } else {
        this.onGoContacts();
      }
    })
  }

  @Builder
  pendingRow(item: PersonBalance) {
    Row({ space: 10 }) {
      Avatar({ name: item.person.name, size: 36 })
      Column({ space: 3 }) {
        Text(item.person.name)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
        Text(`${relationLabel(item.person.relation)} · 收 ${MoneyUtils.format(item.received)} / 送 ${MoneyUtils.format(item.given)}`)
          .fontSize(10)
          .fontColor(AppTheme.textMuted)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(`待回礼 ${MoneyUtils.formatAbs(item.net())}`)
        .fontSize(11)
        .fontColor(AppTheme.warning)
        .backgroundColor(AppTheme.warningSoft)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .borderRadius(8)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppTheme.card)
    .borderRadius(14)
    .onClick(() => {
      this.onGoRecords();
    })
  }

  @Builder
  recentRow(item: FavorRecordView) {
    Row({ space: 10 }) {
      Text(item.record.type === FavorType.RECEIVE ? '收' : '送')
        .width(34)
        .height(34)
        .borderRadius(9)
        .textAlign(TextAlign.Center)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(item.record.type === FavorType.RECEIVE ? AppTheme.received : AppTheme.given)
        .backgroundColor(item.record.type === FavorType.RECEIVE ? AppTheme.receivedSoft : AppTheme.givenSoft)

      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(item.personName)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textPrimary)
          Tag({ text: occasionLabel(item.record.occasion) })
        }
        Text(item.record.date + (item.record.note.length > 0 ? ` · ${item.record.note}` : ''))
          .fontSize(10)
          .fontColor(AppTheme.textMuted)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(`${item.record.type === FavorType.RECEIVE ? '+' : '-'}${MoneyUtils.format(item.record.amount)}`)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(item.record.type === FavorType.RECEIVE ? AppTheme.received : AppTheme.given)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppTheme.card)
    .borderRadius(14)
    .onClick(() => {
      this.onGoRecords();
    })
  }

  @Builder
  loadingView() {
    Row() {
      LoadingProgress()
        .width(36)
        .height(36)
        .color(AppTheme.primary)
    }
    .width('100%')
    .height(200)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      this.header()

      if (this.loading) {
        this.loadingView()
      } else {
        Scroll() {
          Column() {
            this.heroCard()

            Row({ space: 12 }) {
              this.actionCard('✍️', '记一笔', '记录收礼 / 送礼', 'add')
              this.actionCard('👥', '通讯录', '管理往来对象', 'contacts')
            }
            .width('100%')
            .margin({ top: 14 })

            if (this.dashboard.statistics.recordCount === 0) {
              EmptyState({
                icon: '🧧',
                title: '还没有人情记录',
                hint: '从第一笔收礼或送礼开始，慢慢积累属于你的人际账本',
                actionText: this.dashboard.statistics.personCount === 0 ? '载入示例数据' : '去记一笔',
                onAction: (): void => {
                  if (this.dashboard.statistics.personCount === 0) {
                    this.loadSample();
                  } else {
                    this.onAddRecord();
                  }
                }
              })
            } else {
              if (this.dashboard.pendingReturns.length > 0) {
                SectionTitle({
                  title: '待回礼提醒',
                  subtitle: `${this.dashboard.pendingCount} 位`
                })
                Column({ space: 8 }) {
                  ForEach(this.dashboard.pendingReturns, (item: PersonBalance) => {
                    this.pendingRow(item)
                  }, (item: PersonBalance) => item.person.id)
                }
                .width('100%')
              }

              SectionTitle({
                title: '最近往来',
                subtitle: `共 ${this.dashboard.statistics.recordCount} 笔`
              })
              Column({ space: 8 }) {
                ForEach(this.dashboard.recentRecords, (item: FavorRecordView) => {
                  this.recentRow(item)
                }, (item: FavorRecordView) => item.record.id)
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 24 })
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
