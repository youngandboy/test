import { AppTheme } from '@favor/commons';

@Component
export struct Avatar {
  name: string = '';
  size: number = 42;
  color: string = AppTheme.primary;

  build() {
    Text(this.name.length > 0 ? this.name.substring(0, 1) : '?')
      .width(this.size)
      .height(this.size)
      .borderRadius(this.size / 2)
      .textAlign(TextAlign.Center)
      .fontSize(this.size * 0.4)
      .fontWeight(FontWeight.Medium)
      .fontColor(Color.White)
      .backgroundColor(this.color)
  }
}
