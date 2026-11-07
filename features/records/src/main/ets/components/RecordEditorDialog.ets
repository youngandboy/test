import { promptAction } from '@kit.ArkUI';
import { AppTheme, DateUtils, FavorRecord, FavorType, IdUtils, MoneyUtils, Occasion, Person, allOccasions,
  occasionLabel } from '@favor/commons';
import { FavorRepository } from '@favor/data';

/** 新增 / 编辑一笔人情记录。校验、组装记录、写入仓库都在这里完成。 */
@CustomDialog
export struct RecordEditorDialog {
  controller?: CustomDialogController;
  record: FavorRecord | null = null;
  persons: Person[] = [];
  presetPersonId: string = '';
  onSaved: () => void = () => {};
  @State selectedPersonId: string = '';
  @State selectedType: FavorType = FavorType.RECEIVE;
  @State amountText: string = '';
  @State selectedOccasion: Occasion = Occasion.WEDDING;
  @State dateText: string = DateUtils.today();
  @State noteText: string = '';
  @State saving: boolean = false;

  aboutToAppear(): void {
    if (this.record !== null) {
      this.selectedPersonId = this.record.personId;
      this.selectedType = this.record.type;
      this.amountText = `${this.record.amount}`;
      this.selectedOccasion = this.record.occasion;
      this.dateText = this.record.date;
      this.noteText = this.record.note;
    } else if (this.presetPersonId.length > 0 &&
      this.persons.some((person: Person): boolean => person.id === this.presetPersonId)) {
      this.selectedPersonId = this.presetPersonId;
    } else if (this.persons.length > 0) {
      this.selectedPersonId = this.persons[0].id;
    }
  }

  private save(): void {
    if (this.saving) {
      return;
    }
    if (this.selectedPersonId.length === 0) {
      promptAction.showToast({ message: '请选择联系人' });
      return;
    }
    const amount = MoneyUtils.parse(this.amountText);
    if (amount <= 0) {
      promptAction.showToast({ message: '请输入大于 0 的金额' });
      return;
    }
    if (!DateUtils.isValidDate(this.dateText)) {
      promptAction.showToast({ message: '日期格式应为 YYYY-MM-DD' });
      return;
    }
    const item: FavorRecord = {
      id: this.record === null ? IdUtils.next('r') : this.record.id,
      personId: this.selectedPersonId,
      type: this.selectedType,
      amount: amount,
      occasion: this.selectedOccasion,
      date: this.dateText,
      note: this.noteText.trim(),
      createdAt: this.record === null ? Date.now() : this.record.createdAt
    };
    this.saving = true;
    FavorRepository.getInstance().saveRecord(item).then(() => {
      this.onSaved();
      this.controller?.close();
      promptAction.showToast({ message: this.record === null ? '已记一笔' : '已保存修改' });
    }).catch(() => {
      this.saving = false;
      promptAction.showToast({ message: '保存失败，请重试' });
    });
  }

  @Builder
  label(text: string) {
    Text(text)
      .fontSize(12)
      .fontColor(AppTheme.textSecondary)
      .width('100%')
  }

  @Builder
  typeChip(label: string, value: FavorType) {
    Text(label)
      .fontSize(13)
      .fontColor(this.selectedType === value ? Color.White : AppTheme.textSecondary)
      .backgroundColor(this.selectedType === value ?
        (value === FavorType.RECEIVE ? AppTheme.received : AppTheme.given) : AppTheme.track)
      .padding({ left: 18, right: 18, top: 8, bottom: 8 })
      .borderRadius(18)
      .onClick(() => {
        this.selectedType = value;
      })
  }

  @Builder
  personChip(person: Person) {
    Text(person.name)
      .fontSize(12)
      .fontColor(this.selectedPersonId === person.id ? Color.White : AppTheme.textSecondary)
      .backgroundColor(this.selectedPersonId === person.id ? AppTheme.primary : AppTheme.track)
      .padding({ left: 14, right: 14, top: 7, bottom: 7 })
      .borderRadius(16)
      .margin({ right: 8 })
      .onClick(() => {
        this.selectedPersonId = person.id;
      })
  }

  @Builder
  occasionChip(occasion: Occasion) {
    Text(occasionLabel(occasion))
      .fontSize(12)
      .fontColor(this.selectedOccasion === occasion ? Color.White : AppTheme.textSecondary)
      .backgroundColor(this.selectedOccasion === occasion ? AppTheme.primary : AppTheme.track)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(14)
      .margin({ right: 8, bottom: 8 })
      .onClick(() => {
        this.selectedOccasion = occasion;
      })
  }

  build() {
    Column() {
      Row() {
        Text(this.record === null ? '记一笔' : '编辑记录')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.textPrimary)
        Blank()
        Text('✕')
          .fontSize(16)
          .fontColor(AppTheme.textMuted)
          .padding(4)
          .onClick(() => {
            this.controller?.close();
          })
      }
      .width('100%')

      Scroll() {
        Column({ space: 12 }) {
          this.label('类型')
          Row({ space: 8 }) {
            this.typeChip('收礼', FavorType.RECEIVE)
            this.typeChip('送礼', FavorType.GIVE)
          }
          .width('100%')

          this.label('联系人')
          Scroll() {
            Row() {
              ForEach(this.persons, (person: Person) => {
                this.personChip(person)
              }, (person: Person) => person.id)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')

          this.label('金额')
          TextInput({ text: this.amountText, placeholder: '0.00' })
            .type(InputType.NUMBER_DECIMAL)
            .height(40)
            .fontSize(13)
            .backgroundColor(AppTheme.background)
            .borderRadius(10)
            .width('100%')
            .onChange((value: string) => {
              this.amountText = value;
            })

          this.label('场合')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(allOccasions(), (occasion: Occasion) => {
              this.occasionChip(occasion)
            }, (occasion: Occasion) => occasion)
          }
          .width('100%')

          this.label('日期')
          TextInput({ text: this.dateText, placeholder: 'YYYY-MM-DD' })
            .height(40)
            .fontSize(13)
            .backgroundColor(AppTheme.background)
            .borderRadius(10)
            .width('100%')
            .onChange((value: string) => {
              this.dateText = value;
            })

          this.label('备注')
          TextArea({ text: this.noteText, placeholder: '例如：儿子婚礼、中秋回礼（选填）' })
            .height(64)
            .fontSize(13)
            .backgroundColor(AppTheme.background)
            .borderRadius(10)
            .width('100%')
            .onChange((value: string) => {
              this.noteText = value;
            })
        }
        .width('100%')
        .padding({ top: 12, bottom: 4 })
      }
      .constraintSize({ maxHeight: 470 })
      .scrollBar(BarState.Off)
      .width('100%')

      Row({ space: 10 }) {
        Button('取消')
          .layoutWeight(1)
          .height(38)
          .fontSize(14)
          .fontColor(AppTheme.textSecondary)
          .backgroundColor(AppTheme.track)
          .onClick(() => {
            this.controller?.close();
          })
        Button(this.saving ? '保存中' : '保存')
          .layoutWeight(1)
          .height(38)
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor(AppTheme.primary)
          .enabled(!this.saving)
          .onClick(() => {
            this.save();
          })
      }
      .width('100%')
      .margin({ top: 14 })
    }
    .width('92%')
    .padding(18)
    .backgroundColor(AppTheme.card)
    .borderRadius(20)
  }
}
