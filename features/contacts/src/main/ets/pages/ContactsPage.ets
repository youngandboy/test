import { promptAction } from '@kit.ArkUI';
import { AppTheme, FavorAnalytics, FavorRecord, FavorRecordView, FavorStatistics, FavorType, MoneyUtils, Person,
  PersonBalance, emptyPerson, occasionLabel, relationLabel } from '@favor/commons';
import { Avatar, EmptyState, SectionTitle, StatTile, Tag } from '@favor/ui';
import { FavorRepository } from '@favor/data';
import { PersonEditorDialog } from '../components/PersonEditorDialog';

/** 通讯录：联系人列表、单人详情、收送汇总和编辑删除。 */
@Component
export struct ContactsPage {
  onGoRecords: () => void = () => {};
  onAddRecordForPerson: (personId: string) => void = () => {};
  @Prop @Watch('onActiveChanged') active: boolean = true;
  @State balances: PersonBalance[] = [];
  @State keyword: string = '';
  @State loading: boolean = true;
  @State showDetail: boolean = false;
  @State detailPerson: Person = emptyPerson();
  @State detailRecords: FavorRecordView[] = [];
  @State detailStats: FavorStatistics = new FavorStatistics();
  private repo: FavorRepository = FavorRepository.getInstance();
  private editor: CustomDialogController | null = null;

  aboutToAppear(): void {
    this.reload();
  }

  onActiveChanged(): void {
    if (this.active) {
      this.reload();
      if (this.showDetail) {
        this.loadDetail(this.detailPerson);
      }
    }
  }

  private async reload(): Promise<void> {
    try {
      this.balances = await this.repo.getPersonBalances();
    } catch (error) {
      // 读取失败时保留列表状态，用户可以重试。
    }
    this.loading = false;
  }

  private filteredBalances(): PersonBalance[] {
    const keyword = this.keyword.trim();
    const result: PersonBalance[] = keyword.length === 0 ? this.balances.slice() :
      this.balances.filter((item: PersonBalance): boolean => {
        return item.person.name.includes(keyword) || item.person.phone.includes(keyword) ||
          relationLabel(item.person.relation).includes(keyword);
      });
    result.sort((left: PersonBalance, right: PersonBalance): number => {
      if (left.person.name === right.person.name) {
        return 0;
      }
      return left.person.name < right.person.name ? -1 : 1;
    });
    return result;
  }

  private async openDetail(item: PersonBalance): Promise<void> {
    this.showDetail = true;
    this.detailPerson = item.person;
    await this.loadDetail(item.person);
  }

  private async loadDetail(person: Person): Promise<void> {
    try {
      const views = await this.repo.getRecordViews();
      this.detailRecords = views.filter((item: FavorRecordView): boolean => item.record.personId === person.id);
      const rawRecords: FavorRecord[] = this.detailRecords.map((item: FavorRecordView): FavorRecord => item.record);
      this.detailStats = FavorAnalytics.statistics(rawRecords);
    } catch (error) {
      this.detailRecords = [];
      this.detailStats = new FavorStatistics();
    }
  }

  private openEditor(person: Person | null): void {
    const dialog = new CustomDialogController({
      builder: PersonEditorDialog({
        person: person,
        onSaved: (): void => {
          this.handleSaved();
        }
      }),
      autoCancel: true,
      customStyle: true
    });
    this.editor = dialog;
    dialog.open();
  }

  private async handleSaved(): Promise<void> {
    await this.reload();
    if (this.showDetail) {
      const updated = await this.repo.getPerson(this.detailPerson.id);
      if (updated !== null) {
        this.detailPerson = updated;
        await this.loadDetail(updated);
      } else {
        this.showDetail = false;
      }
    }
  }

  private confirmDelete(): void {
    AlertDialog.show({
      title: '删除联系人',
      message: `删除「${this.detailPerson.name}」后，其名下 ${this.detailRecords.length} 笔人情记录也会一并删除。`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: AppTheme.primary,
        action: () => {
          this.removePerson();
        }
      }
    });
  }

  private async removePerson(): Promise<void> {
    try {
      await this.repo.deletePerson(this.detailPerson.id);
      this.showDetail = false;
      await this.reload();
      promptAction.showToast({ message: '联系人已删除' });
    } catch (error) {
      promptAction.showToast({ message: '删除失败，请重试' });
    }
  }

  @Builder
  header() {
    Row() {
      Column({ space: 3 }) {
        Text('通讯录')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.textPrimary)
        Text(`${this.balances.length} 位往来对象`)
          .fontSize(11)
          .fontColor(AppTheme.textMuted)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button('+ 添加')
        .height(36)
        .fontSize(13)
        .fontColor(Color.White)
        .backgroundColor(AppTheme.primary)
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          this.openEditor(null);
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 10 })
  }

  @Builder
  personCard(item: PersonBalance) {
    Row({ space: 12 }) {
      Avatar({ name: item.person.name, avatarSize: 46 })
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(item.person.name)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textPrimary)
          Tag({ text: relationLabel(item.person.relation) })
        }
        Text(item.person.phone.length > 0 ? item.person.phone : '未填写手机号')
          .fontSize(11)
          .fontColor(AppTheme.textMuted)
        if (item.person.note.length > 0) {
          Text(item.person.note)
            .fontSize(10)
            .fontColor(AppTheme.textMuted)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column({ space: 3 }) {
        Text(AppTheme.netStatus(item.net()))
          .fontSize(11)
          .fontColor(AppTheme.netColor(item.net()))
        Text(MoneyUtils.formatAbs(item.net()))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.netColor(item.net()))
        Text(`${item.recordCount} 笔`)
          .fontSize(10)
          .fontColor(AppTheme.textMuted)
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding(13)
    .backgroundColor(AppTheme.card)
    .borderRadius(14)
    .onClick(() => {
      this.openDetail(item);
    })
  }

  @Builder
  detailHeader() {
    Row({ space: 8 }) {
      Text('←')
        .fontSize(24)
        .fontColor(AppTheme.primary)
        .padding({ right: 4 })
        .onClick(() => {
          this.showDetail = false;
        })
      Text('联系人详情')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.textPrimary)
      Blank()
      Text('编辑')
        .fontSize(13)
        .fontColor(AppTheme.primary)
        .padding(6)
        .onClick(() => {
          this.openEditor(this.detailPerson);
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 10 })
  }

  @Builder
  detailRecordRow(item: FavorRecordView) {
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
          Text(occasionLabel(item.record.occasion))
            .fontSize(13)
            .fontColor(AppTheme.textPrimary)
          Text(item.record.date)
            .fontSize(10)
            .fontColor(AppTheme.textMuted)
        }
        if (item.record.note.length > 0) {
          Text(item.record.note)
            .fontSize(10)
            .fontColor(AppTheme.textMuted)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
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
    .borderRadius(12)
    .onClick(() => {
      this.onGoRecords();
    })
  }

  @Builder
  detailView() {
    Column() {
      this.detailHeader()
      Scroll() {
        Column({ space: 12 }) {
          Row({ space: 14 }) {
            Avatar({ name: this.detailPerson.name, avatarSize: 56 })
            Column({ space: 5 }) {
              Row({ space: 6 }) {
                Text(this.detailPerson.name)
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.textPrimary)
                Tag({ text: relationLabel(this.detailPerson.relation) })
              }
              if (this.detailPerson.phone.length > 0) {
                Text(this.detailPerson.phone)
                  .fontSize(12)
                  .fontColor(AppTheme.textSecondary)
              }
              if (this.detailPerson.note.length > 0) {
                Text(this.detailPerson.note)
                  .fontSize(11)
                  .fontColor(AppTheme.textMuted)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding(16)
          .backgroundColor(AppTheme.card)
          .borderRadius(16)

          Row({ space: 8 }) {
            StatTile({
              label: '累计收礼',
              value: MoneyUtils.format(this.detailStats.received),
              color: AppTheme.received
            })
            StatTile({
              label: '累计送礼',
              value: MoneyUtils.format(this.detailStats.given),
              color: AppTheme.given
            })
            StatTile({
              label: AppTheme.netStatus(this.detailStats.net()),
              value: MoneyUtils.formatAbs(this.detailStats.net()),
              color: AppTheme.netColor(this.detailStats.net())
            })
          }
          .width('100%')

          SectionTitle({ title: '往来记录', subtitle: `${this.detailRecords.length} 笔` })
          if (this.detailRecords.length === 0) {
            EmptyState({
              icon: '📒',
              title: '还没有往来记录',
              hint: '和 TA 的每一笔人情都会出现在这里',
              actionText: '去记一笔',
              onAction: (): void => {
                this.onAddRecordForPerson(this.detailPerson.id);
              }
            })
          } else {
            Column({ space: 8 }) {
              ForEach(this.detailRecords, (item: FavorRecordView) => {
                this.detailRecordRow(item)
              }, (item: FavorRecordView) => item.record.id)
            }
            .width('100%')
          }

          Row({ space: 10 }) {
            Button('去记一笔')
              .layoutWeight(1)
              .height(40)
              .fontSize(14)
              .fontColor(Color.White)
              .backgroundColor(AppTheme.primary)
              .onClick(() => {
                this.onAddRecordForPerson(this.detailPerson.id);
              })
            Button('删除联系人')
              .layoutWeight(1)
              .height(40)
              .fontSize(14)
              .fontColor(AppTheme.primary)
              .backgroundColor(AppTheme.receivedSoft)
              .onClick(() => {
                this.confirmDelete();
              })
          }
          .width('100%')
          .margin({ top: 8, bottom: 24 })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Column() {
      if (this.showDetail) {
        this.detailView()
      } else {
        this.header()

        Row() {
          TextInput({ placeholder: '搜索姓名、关系或手机号' })
            .height(38)
            .fontSize(12)
            .backgroundColor(AppTheme.card)
            .borderRadius(10)
            .width('100%')
            .padding({ left: 12, right: 12 })
            .onChange((value: string) => {
              this.keyword = value;
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 10 })

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
        } else if (this.balances.length === 0) {
          EmptyState({
            icon: '👥',
            title: '通讯录还是空的',
            hint: '先添加要往来的人，再记录每一笔收礼和送礼',
            actionText: '添加联系人',
            onAction: (): void => {
              this.openEditor(null);
            }
          })
        } else if (this.filteredBalances().length === 0) {
          EmptyState({
            icon: '🔍',
            title: '没有找到联系人',
            hint: '换个姓名、关系或手机号试试'
          })
        } else {
          List({ space: 8 }) {
            ForEach(this.filteredBalances(), (item: PersonBalance) => {
              ListItem() {
                this.personCard(item)
              }
            }, (item: PersonBalance) => item.person.id)
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
          .padding({ left: 16, right: 16, bottom: 16 })
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.background)
  }
}
