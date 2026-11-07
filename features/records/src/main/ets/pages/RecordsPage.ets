import { promptAction } from '@kit.ArkUI';
import { AppTheme, FavorRecord, FavorRecordView, FavorType, MoneyUtils, Person, favorTypeLabel,
  occasionLabel } from '@favor/commons';
import { EmptyState, Tag } from '@favor/ui';
import { FavorRepository } from '@favor/data';
import { RecordEditorDialog } from '../components/RecordEditorDialog';

/** 人情账：按收/送筛选、搜索，支持新增、编辑和长按删除。 */
@Component
export struct RecordsPage {
  onGoContacts: () => void = () => {};
  @Prop @Watch('onActiveChanged') active: boolean = true;
  @Prop presetPersonId: string = '';
  @Prop @Watch('onAddTokenChanged') addToken: number = 0;
  @State records: FavorRecordView[] = [];
  @State persons: Person[] = [];
  @State filter: string = 'all';
  @State keyword: string = '';
  @State loading: boolean = true;
  @State handledToken: number = 0;
  private repo: FavorRepository = FavorRepository.getInstance();
  private editor: CustomDialogController | null = null;

  aboutToAppear(): void {
    this.reload();
    this.consumeAddToken();
  }

  onActiveChanged(): void {
    if (this.active) {
      this.reload();
    }
  }

  onAddTokenChanged(): void {
    this.consumeAddToken();
  }

  private consumeAddToken(): void {
    if (this.addToken > 0 && this.addToken !== this.handledToken) {
      this.handledToken = this.addToken;
      this.openNewRecord();
    }
  }

  private async reload(): Promise<void> {
    try {
      this.records = await this.repo.getRecordViews();
      this.persons = await this.repo.getPersons();
    } catch (error) {
      // 保持现有列表，避免读取异常导致页面空白。
    }
    this.loading = false;
  }

  private async openNewRecord(): Promise<void> {
    await this.reload();
    this.openEditor(null, this.presetPersonId);
  }

  private openEditor(item: FavorRecordView | null, presetPersonId: string): void {
    if (this.persons.length === 0) {
      promptAction.showToast({ message: '请先在通讯录添加联系人' });
      this.onGoContacts();
      return;
    }
    const existing: FavorRecord | null = item === null ? null : item.record;
    const dialog = new CustomDialogController({
      builder: RecordEditorDialog({
        record: existing,
        persons: this.persons,
        presetPersonId: presetPersonId,
        onSaved: (): void => {
          this.reload();
        }
      }),
      autoCancel: true,
      customStyle: true
    });
    this.editor = dialog;
    dialog.open();
  }

  private confirmDelete(item: FavorRecordView): void {
    AlertDialog.show({
      title: '删除人情记录',
      message: `确定删除与「${item.personName}」的这笔${favorTypeLabel(item.record.type)}记录吗？`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: AppTheme.primary,
        action: () => {
          this.removeRecord(item.record.id);
        }
      }
    });
  }

  private async removeRecord(id: string): Promise<void> {
    try {
      await this.repo.deleteRecord(id);
      await this.reload();
      promptAction.showToast({ message: '已删除' });
    } catch (error) {
      promptAction.showToast({ message: '删除失败，请重试' });
    }
  }

  private filteredRecords(): FavorRecordView[] {
    const keyword = this.keyword.trim();
    return this.records.filter((item: FavorRecordView): boolean => {
      if (this.filter === 'receive' && item.record.type !== FavorType.RECEIVE) {
        return false;
      }
      if (this.filter === 'give' && item.record.type !== FavorType.GIVE) {
        return false;
      }
      if (keyword.length === 0) {
        return true;
      }
      return item.personName.includes(keyword) || item.record.note.includes(keyword) ||
        occasionLabel(item.record.occasion).includes(keyword);
    });
  }

  @Builder
  header() {
    Row() {
      Column({ space: 3 }) {
        Text('人情账')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.textPrimary)
        Text(`共 ${this.records.length} 笔往来 · 长按记录可删除`)
          .fontSize(11)
          .fontColor(AppTheme.textMuted)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button('+ 记一笔')
        .height(36)
        .fontSize(13)
        .fontColor(Color.White)
        .backgroundColor(AppTheme.primary)
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          this.openEditor(null, '');
        })
    }
    .width('100%')
    .padding({ top: 14, bottom: 10 })
  }

  @Builder
  filterChip(label: string, value: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.filter === value ? Color.White : AppTheme.textSecondary)
      .backgroundColor(this.filter === value ? AppTheme.primary : AppTheme.card)
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .borderRadius(16)
      .onClick(() => {
        this.filter = value;
      })
  }

  @Builder
  recordRow(item: FavorRecordView) {
    Row({ space: 10 }) {
      Text(item.record.type === FavorType.RECEIVE ? '收' : '送')
        .width(36)
        .height(36)
        .borderRadius(10)
        .textAlign(TextAlign.Center)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(item.record.type === FavorType.RECEIVE ? AppTheme.received : AppTheme.given)
        .backgroundColor(item.record.type === FavorType.RECEIVE ? AppTheme.receivedSoft : AppTheme.givenSoft)

      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(item.personName)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textPrimary)
          Tag({ text: occasionLabel(item.record.occasion) })
        }
        Text(item.record.date + (item.record.note.length > 0 ? ` · ${item.record.note}` : ''))
          .fontSize(11)
          .fontColor(AppTheme.textMuted)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(`${item.record.type === FavorType.RECEIVE ? '+' : '-'}${MoneyUtils.format(item.record.amount)}`)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(item.record.type === FavorType.RECEIVE ? AppTheme.received : AppTheme.given)
    }
    .width('100%')
    .padding(13)
    .backgroundColor(AppTheme.card)
    .borderRadius(14)
    .onClick(() => {
      this.openEditor(item, '');
    })
    .gesture(LongPressGesture().onAction(() => {
      this.confirmDelete(item);
    }))
  }

  build() {
    Column() {
      this.header()

      TextInput({ placeholder: '搜索联系人、场合或备注' })
        .height(38)
        .fontSize(12)
        .backgroundColor(AppTheme.card)
        .borderRadius(10)
        .width('100%')
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.keyword = value;
        })

      Row({ space: 8 }) {
        this.filterChip('全部', 'all')
        this.filterChip('收礼', 'receive')
        this.filterChip('送礼', 'give')
      }
      .width('100%')
      .padding({ top: 10, bottom: 10 })

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
      } else if (this.filteredRecords().length === 0) {
        EmptyState({
          icon: '📒',
          title: this.records.length === 0 ? '还没有人情记录' : '没有匹配的记录',
          hint: this.records.length === 0 ? '收礼、送礼都记下来，回礼时才不会遗漏' : '换个关键词或筛选条件试试',
          actionText: this.records.length === 0 ? '记一笔' : '',
          onAction: (): void => {
            this.openEditor(null, '');
          }
        })
      } else {
        List({ space: 8 }) {
          ForEach(this.filteredRecords(), (item: FavorRecordView) => {
            ListItem() {
              this.recordRow(item)
            }
          }, (item: FavorRecordView) => item.record.id)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .padding({ bottom: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
    .backgroundColor(AppTheme.background)
  }
}
