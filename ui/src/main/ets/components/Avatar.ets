import { AppTheme } from '@favor/commons';

@Component
export struct Avatar {
  name: string = '';
  avatarSize: number = 42;
  color: string = AppTheme.primary;

  build() {
    Text(this.name.length > 0 ? this.name.substring(0, 1) : '?')
      .width(this.avatarSize)
      .height(this.avatarSize)
      .borderRadius(this.avatarSize / 2)
      .textAlign(TextAlign.Center)
      .fontSize(this.avatarSize * 0.4)
      .fontWeight(FontWeight.Medium)
      .fontColor(Color.White)
      .backgroundColor(this.color)
  }
}
