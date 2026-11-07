import { AppTheme } from '@favor/commons';

@Component
export struct Tag {
  text: string = '';
  color: string = AppTheme.textSecondary;
  background: string = AppTheme.track;

  build() {
    Text(this.text)
      .fontSize(11)
      .fontColor(this.color)
      .backgroundColor(this.background)
      .borderRadius(6)
      .padding({ left: 7, right: 7, top: 3, bottom: 3 })
  }
}
