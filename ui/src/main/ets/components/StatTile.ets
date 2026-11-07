import { AppTheme } from '@favor/commons';

@Component
export struct StatTile {
  label: string = '';
  value: string = '';
  color: string = AppTheme.textPrimary;
  background: string = AppTheme.card;

  build() {
    Column({ space: 6 }) {
      Text(this.label)
        .fontSize(11)
        .fontColor(AppTheme.textSecondary)
      Text(this.value)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.color)
    }
    .layoutWeight(1)
    .padding({ top: 12, bottom: 12, left: 12, right: 12 })
    .backgroundColor(this.background)
    .borderRadius(AppTheme.radiusSmall)
    .alignItems(HorizontalAlign.Start)
  }
}
