import { AppTheme } from '@favor/commons';

@Component
export struct SectionTitle {
  title: string = '';
  subtitle: string = '';

  build() {
    Row() {
      Text(this.title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.textPrimary)
      Blank()
      if (this.subtitle.length > 0) {
        Text(this.subtitle)
          .fontSize(11)
          .fontColor(AppTheme.textMuted)
      }
    }
    .width('100%')
    .margin({ top: 18, bottom: 10 })
  }
}
