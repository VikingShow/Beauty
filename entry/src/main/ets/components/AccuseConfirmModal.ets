import { Exhibit, findExhibit } from '../scenes/Exhibits';

/**
 * 指认前确认对话框：避免手滑触发最终指认。
 * 取消 / 确认 两个按钮，点背景蒙层也算取消。
 */
@Component
export struct AccuseConfirmModal {
  @Prop @Watch('onVisibleChange') visible: boolean = false;
  @Prop exhibitId: string = '';
  onCancel: () => void = () => {};
  onConfirm: () => void = () => {};

  @State private backdropOpacity: number = 0;
  @State private contentOpacity: number = 0;
  @State private contentOffsetY: number = 16;

  onVisibleChange(): void {
    if (this.visible) {
      animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.backdropOpacity = 1;
      });
      setTimeout(() => {
        animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
          this.contentOpacity = 1;
          this.contentOffsetY = 0;
        });
      }, 40);
    } else {
      this.backdropOpacity = 0;
      this.contentOpacity = 0;
      this.contentOffsetY = 16;
    }
  }

  build() {
    if (this.visible) {
      Stack() {
        // 蒙层
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#D0000000')
          .opacity(this.backdropOpacity)
          .onClick(() => {
            this.onCancel();
          })

        // 卡片
        Column({ space: 14 }) {
          Text('最 终 指 认')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#d4b678')
            .letterSpacing(8)

          Divider()
            .strokeWidth(1)
            .color('#55d4b678')

          Text('你确定要指认这幅')
            .fontSize(14)
            .fontColor('#c9c9b4')
            .lineHeight(22)

          Text('《' + this.getTitle() + '》')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f5e6c8')
            .letterSpacing(2)

          Text('即为《公正法官》的藏身处吗？')
            .fontSize(14)
            .fontColor('#c9c9b4')
            .lineHeight(22)

          Text('此刻将揭晓真相，机会仅有一次判断。')
            .fontSize(12)
            .fontColor('#8a8a9a')
            .letterSpacing(2)
            .margin({ top: 4 })

          Row({ space: 16 }) {
            Button('取消', { type: ButtonType.Capsule })
              .height(40)
              .fontSize(14)
              .backgroundColor('#E61a1a2e')
              .fontColor('#d4b678')
              .borderColor('#55d4b678')
              .borderWidth(1)
              .padding({ left: 32, right: 32 })
              .onClick(() => {
                this.onCancel();
              })

            Button('确认指认', { type: ButtonType.Capsule })
              .height(40)
              .fontSize(14)
              .fontColor('#0a0a1a')
              .fontWeight(FontWeight.Medium)
              .backgroundColor('#d4b678')
              .borderColor('#d4b678')
              .borderWidth(1)
              .padding({ left: 32, right: 32 })
              .onClick(() => {
                this.onConfirm();
              })
          }
          .margin({ top: 10 })
        }
        .width(480)
        .padding({ left: 32, right: 32, top: 28, bottom: 26 })
        .backgroundColor('#F20a0a1a')
        .borderColor('#88d4b678')
        .borderWidth(1)
        .borderRadius(14)
        .alignItems(HorizontalAlign.Center)
        .opacity(this.contentOpacity)
        .translate({ y: this.contentOffsetY })
      }
      .width('100%')
      .height('100%')
      .alignContent(Alignment.Center)
      .hitTestBehavior(HitTestMode.Default)
    }
  }

  private getTitle(): string {
    const e: Exhibit | undefined = findExhibit(this.exhibitId);
    return e !== undefined ? e.titleZh : '';
  }
}
