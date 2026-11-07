import { AppTheme } from '@favor/commons';
import { HomePage } from '@favor/feature-home';
import { RecordsPage } from '@favor/feature-records';
import { ContactsPage } from '@favor/feature-contacts';
import { StatisticsPage } from '@favor/feature-statistics';

/**
 * 应用壳：只负责底部导航、Tab 切换和跨 Tab 的“记一笔”指令，
 * 具体业务全部下沉到四个功能模块。
 */
@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State recordsAddToken: number = 0;
  @State recordsPresetPersonId: string = '';

  private goAddRecord(): void {
    this.recordsPresetPersonId = '';
    this.currentIndex = 1;
    this.recordsAddToken += 1;
  }

  private goAddRecordForPerson(personId: string): void {
    this.recordsPresetPersonId = personId;
    this.currentIndex = 1;
    this.recordsAddToken += 1;
  }

  @Builder
  tabBar(index: number, title: string, icon: string) {
    Column({ space: 2 }) {
      Text(icon)
        .fontSize(index === this.currentIndex ? 21 : 19)
      Text(title)
        .fontSize(10)
        .fontColor(index === this.currentIndex ? AppTheme.primary : AppTheme.textMuted)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        HomePage({
          active: this.currentIndex === 0,
          onGoRecords: (): void => {
            this.currentIndex = 1;
          },
          onGoContacts: (): void => {
            this.currentIndex = 2;
          },
          onAddRecord: (): void => {
            this.goAddRecord();
          }
        })
      }
      .tabBar(this.tabBar(0, '首页', '🏠'))

      TabContent() {
        RecordsPage({
          active: this.currentIndex === 1,
          addToken: this.recordsAddToken,
          presetPersonId: this.recordsPresetPersonId,
          onGoContacts: (): void => {
            this.currentIndex = 2;
          }
        })
      }
      .tabBar(this.tabBar(1, '人情账', '📒'))

      TabContent() {
        ContactsPage({
          active: this.currentIndex === 2,
          onGoRecords: (): void => {
            this.currentIndex = 1;
          },
          onAddRecordForPerson: (personId: string): void => {
            this.goAddRecordForPerson(personId);
          }
        })
      }
      .tabBar(this.tabBar(2, '通讯录', '👥'))

      TabContent() {
        StatisticsPage({
          active: this.currentIndex === 3,
          onAddRecord: (): void => {
            this.goAddRecord();
          }
        })
      }
      .tabBar(this.tabBar(3, '统计', '📊'))
    }
    .barHeight(58)
    .barBackgroundColor(Color.White)
    .scrollable(false)
    .onChange((index: number) => {
      this.currentIndex = index;
    })
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.background)
  }
}
