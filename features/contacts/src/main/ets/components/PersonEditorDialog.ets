import { promptAction } from '@kit.ArkUI';
import { allRelations, AppTheme, IdUtils, Person, Relation, relationLabel } from '@favor/commons';
import { FavorRepository } from '@favor/data';

/** 新增 / 编辑联系人。 */
@CustomDialog
export struct PersonEditorDialog {
  controller?: CustomDialogController;
  person: Person | null = null;
  onSaved: () => void = () => {};
  @State nameText: string = '';
  @State selectedRelation: Relation = Relation.FRIEND;
  @State phoneText: string = '';
  @State noteText: string = '';
  @State saving: boolean = false;

  aboutToAppear(): void {
    if (this.person !== null) {
      this.nameText = this.person.name;
      this.selectedRelation = this.person.relation;
      this.phoneText = this.person.phone;
      this.noteText = this.person.note;
    }
  }

  private save(): void {
    if (this.saving) {
      return;
    }
    const name = this.nameText.trim();
    if (name.length === 0) {
      promptAction.showToast({ message: '请输入联系人姓名' });
      return;
    }
    const item: Person = {
      id: this.person === null ? IdUtils.next('p') : this.person.id,
      name: name,
      relation: this.selectedRelation,
      phone: this.phoneText.trim(),
      note: this.noteText.trim(),
      createdAt: this.person === null ? Date.now() : this.person.createdAt
    };
    this.saving = true;
    FavorRepository.getInstance().savePerson(item).then(() => {
      this.onSaved();
      this.controller?.close();
      promptAction.showToast({ message: this.person === null ? '联系人已添加' : '联系人已更新' });
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
  relationChip(relation: Relation) {
    Text(relationLabel(relation))
      .fontSize(12)
      .fontColor(this.selectedRelation === relation ? Color.White : AppTheme.textSecondary)
      .backgroundColor(this.selectedRelation === relation ? AppTheme.primary : AppTheme.track)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(14)
      .margin({ right: 8, bottom: 8 })
      .onClick(() => {
        this.selectedRelation = relation;
      })
  }

  build() {
    Column() {
      Row() {
        Text(this.person === null ? '添加联系人' : '编辑联系人')
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

      Column({ space: 12 }) {
        this.label('姓名')
        TextInput({ text: this.nameText, placeholder: '对方怎么称呼' })
          .height(40)
          .fontSize(13)
          .backgroundColor(AppTheme.background)
          .borderRadius(10)
          .width('100%')
          .onChange((value: string) => {
            this.nameText = value;
          })

        this.label('关系')
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(allRelations(), (relation: Relation) => {
            this.relationChip(relation)
          }, (relation: Relation) => relation)
        }
        .width('100%')

        this.label('手机号')
        TextInput({ text: this.phoneText, placeholder: '选填' })
          .type(InputType.PhoneNumber)
          .height(40)
          .fontSize(13)
          .backgroundColor(AppTheme.background)
          .borderRadius(10)
          .width('100%')
          .onChange((value: string) => {
            this.phoneText = value;
          })

        this.label('备注')
        TextArea({ text: this.noteText, placeholder: '例如：同小区、孩子同班（选填）' })
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
      .padding({ top: 12 })

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
      .margin({ top: 16 })
    }
    .width('92%')
    .padding(18)
    .backgroundColor(AppTheme.card)
    .borderRadius(20)
  }
}
