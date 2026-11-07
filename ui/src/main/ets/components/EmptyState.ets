import { AppTheme } from '@favor/commons';

@Component
export struct EmptyState {
  icon: string = '📭';
  title: string = '暂无数据';
  hint: string = '';
  actionText: string = '';
  onAction: () => void = () => {};

  build() {
    Column({ space: 8 }) {
      Text(this.icon)
        .fontSize(42)
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.textPrimary)
      if (this.hint.length > 0) {
        Text(this.hint)
          .fontSize(12)
          .fontColor(AppTheme.textMuted)
          .textAlign(TextAlign.Center)
          .lineHeight(18)
      }
      if (this.actionText.length > 0) {
        Button(this.actionText)
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor(AppTheme.primary)
          .height(34)
          .padding({ left: 18, right: 18 })
          .margin({ top: 8 })
          .onClick(() => {
            this.onAction();
          })
      }
    }
    .width('100%')
    .padding({ top: 40, bottom: 40, left: 24, right: 24 })
    .alignItems(HorizontalAlign.Center)
  }
}
