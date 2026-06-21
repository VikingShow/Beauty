/**
 * 设置弹窗：语音旁白开关 + 背景音乐开关。
 */
@Component
export struct SettingsModal {
  @Prop @Watch('onVisibleChange') visible: boolean = false;
  @Prop voiceOn: boolean = true;
  @Prop musicOn: boolean = false;
  onClose: () => void = () => {};
  onVoiceToggle: () => void = () => {};
  onMusicToggle: () => void = () => {};

  @State private backdropOpacity: number = 0;
  @State private contentOpacity: number = 0;

  onVisibleChange(): void {
    if (this.visible) {
      animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.backdropOpacity = 1; });
      setTimeout(() => {
        animateTo({ duration: 260, curve: Curve.EaseOut }, () => { this.contentOpacity = 1; });
      }, 40);
    } else {
      this.backdropOpacity = 0;
      this.contentOpacity = 0;
    }
  }

  build() {
    if (this.visible) {
      Stack() {
        Column()
          .width('100%').height('100%')
          .backgroundColor('#E8000000')
          .opacity(this.backdropOpacity)
          .onClick(() => { this.onClose(); })

        Column({ space: 16 }) {
          Text('设 置')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#d4b678')
            .letterSpacing(6)
            .margin({ bottom: 8 })

          Divider().strokeWidth(1).color('#33d4b678')

          this.buildToggle(
            '语音旁白',
            'AI 语音讲解画作与线索',
            this.voiceOn,
            (): void => { this.onVoiceToggle(); }
          )

          this.buildToggle(
            '背景音乐',
            '文艺复兴时期古典乐',
            this.musicOn,
            (): void => { this.onMusicToggle(); }
          )

          Divider().strokeWidth(1).color('#33d4b678').margin({ top: 4 })

          Button('关闭', { type: ButtonType.Capsule })
            .fontSize(13).height(36)
            .backgroundColor('#E61a1a2e').fontColor('#d4b678')
            .borderColor('#d4b67855').borderWidth(1)
            .padding({ left: 32, right: 32 })
            .onClick(() => { this.onClose(); })
        }
        .width(340)
        .padding({ left: 28, right: 28, top: 24, bottom: 24 })
        .backgroundColor('#F20a0a1a')
        .borderColor('#88d4b678').borderWidth(1)
        .borderRadius(14)
        .opacity(this.contentOpacity)
      }
      .width('100%').height('100%')
      .alignContent(Alignment.Center)
    }
  }

  @Builder
  buildToggle(label: string, desc: string, on: boolean, action: () => void) {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text(label)
          .fontSize(15).fontWeight(FontWeight.Medium).fontColor('#f5e6c8')
        Text(desc)
          .fontSize(11).fontColor('#6a6a7a')
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: on })
        .selectedColor('#d4b678')
        .switchPointColor('#0a0a1a')
        .onChange(() => { action(); })
    }
    .width('100%')
    .padding({ left: 12, right: 4, top: 10, bottom: 10 })
    .backgroundColor('#E6101020')
    .borderRadius(10)
  }
}
