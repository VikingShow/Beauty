@Component
export struct GSEffectPanel {
  @Prop visible: boolean = false;
  @State selectedEffect: string = 'none';
  onApplyRetro: () => void = () => {};
  onApplyComic: () => void = () => {};
  onApplyObraDinn: () => void = () => {};
  onApplyColorEdit: () => void = () => {};
  onClearEffect: () => void = () => {};

  build() {
    if (this.visible) {
      Column({ space: 10 }) {
        Text('3DGS 特效')
          .fontSize(14)
          .fontColor('#c4a6e8')
          .fontWeight(FontWeight.Medium)
          .letterSpacing(2)

        Column({ space: 6 }) {
          this.effectButton('无特效', 'none')
          this.effectButton('复古风格', 'retro')
          this.effectButton('漫画风格', 'comic')
          this.effectButton('黑白风格', 'obradinn')
          this.effectButton('颜色调整', 'color')
        }

        Text('提示: 特效功能需要 API 23+')
          .fontSize(9)
          .fontColor('#6a4a8a')
          .margin({ top: 4 })
      }
      .padding(12)
      .backgroundColor('#1a0a2e')
      .borderRadius(10)
      .border({ width: 1, color: '#6a4a8a', style: BorderStyle.Solid, radius: 10 })
    }
  }

  @Builder
  effectButton(label: string, id: string) {
    Button(label)
      .height(32)
      .width('100%')
      .fontSize(12)
      .backgroundColor(this.selectedEffect === id ? '#6a4a8a' : '#2a1a3e')
      .fontColor(this.selectedEffect === id ? '#ffffff' : '#c4a6e8')
      .borderRadius(6)
      .onClick(() => {
        this.selectedEffect = id;
        if (id === 'retro') {
          this.onApplyRetro();
        } else if (id === 'comic') {
          this.onApplyComic();
        } else if (id === 'obradinn') {
          this.onApplyObraDinn();
        } else if (id === 'color') {
          this.onApplyColorEdit();
        } else {
          this.onClearEffect();
        }
      })
  }
}
