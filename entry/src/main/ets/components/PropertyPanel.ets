@Component
export struct PropertyPanel {
  @Prop name: string = '';
  @Prop posX: number = 0;
  @Prop posY: number = 0;
  @Prop posZ: number = 0;
  @Prop rotY: number = 0;
  @Prop scaleVal: number = 1.0;
  @Prop editorMode: string = 'navigate';
  onNudge: (dx: number, dy: number, dz: number) => void = () => {};
  onRotate: (deg: number) => void = () => {};
  onScale: (factor: number) => void = () => {};
  onConfirm: () => void = () => {};
  onDelete: () => void = () => {};
  onCancel: () => void = () => {};

  build() {
    Column({ space: 8 }) {
      Text(this.name)
        .fontSize(14)
        .fontColor('#f5e6c8')
        .fontWeight(FontWeight.Medium)

      Row({ space: 6 }) {
        Text('X')
          .fontSize(11)
          .fontColor('#8a8a9a')
          .width(16)
        Button('-')
          .width(28).height(28).fontSize(12)
          .backgroundColor('#1a1a2e').fontColor('#d4b678')
          .onClick(() => { this.onNudge(-0.1, 0, 0); })
        Text(this.posX.toFixed(2))
          .fontSize(11).fontColor('#d4b678').width(50).textAlign(TextAlign.Center)
        Button('+')
          .width(28).height(28).fontSize(12)
          .backgroundColor('#1a1a2e').fontColor('#d4b678')
          .onClick(() => { this.onNudge(0.1, 0, 0); })
      }

      Row({ space: 6 }) {
        Text('Y')
          .fontSize(11)
          .fontColor('#8a8a9a')
          .width(16)
        Button('-')
          .width(28).height(28).fontSize(12)
          .backgroundColor('#1a1a2e').fontColor('#d4b678')
          .onClick(() => { this.onNudge(0, -0.1, 0); })
        Text(this.posY.toFixed(2))
          .fontSize(11).fontColor('#d4b678').width(50).textAlign(TextAlign.Center)
        Button('+')
          .width(28).height(28).fontSize(12)
          .backgroundColor('#1a1a2e').fontColor('#d4b678')
          .onClick(() => { this.onNudge(0, 0.1, 0); })
      }

      Row({ space: 6 }) {
        Text('Z')
          .fontSize(11)
          .fontColor('#8a8a9a')
          .width(16)
        Button('-')
          .width(28).height(28).fontSize(12)
          .backgroundColor('#1a1a2e').fontColor('#d4b678')
          .onClick(() => { this.onNudge(0, 0, -0.1); })
        Text(this.posZ.toFixed(2))
          .fontSize(11).fontColor('#d4b678').width(50).textAlign(TextAlign.Center)
        Button('+')
          .width(28).height(28).fontSize(12)
          .backgroundColor('#1a1a2e').fontColor('#d4b678')
          .onClick(() => { this.onNudge(0, 0, 0.1); })
      }

      Row({ space: 6 }) {
        Text('旋转')
          .fontSize(11)
          .fontColor('#8a8a9a')
          .width(30)
        Button('-15°')
          .height(28).fontSize(11)
          .backgroundColor('#1a1a2e').fontColor('#d4b678')
          .onClick(() => { this.onRotate(-15); })
        Text(this.rotY + '°')
          .fontSize(11).fontColor('#d4b678').width(50).textAlign(TextAlign.Center)
        Button('+15°')
          .height(28).fontSize(11)
          .backgroundColor('#1a1a2e').fontColor('#d4b678')
          .onClick(() => { this.onRotate(15); })
      }

      Row({ space: 6 }) {
        Text('缩放')
          .fontSize(11)
          .fontColor('#8a8a9a')
          .width(30)
        Button('-10%')
          .height(28).fontSize(11)
          .backgroundColor('#1a1a2e').fontColor('#d4b678')
          .onClick(() => { this.onScale(0.9); })
        Text(this.scaleVal.toFixed(2) + 'x')
          .fontSize(11).fontColor('#d4b678').width(50).textAlign(TextAlign.Center)
        Button('+10%')
          .height(28).fontSize(11)
          .backgroundColor('#1a1a2e').fontColor('#d4b678')
          .onClick(() => { this.onScale(1.1); })
      }

      Row({ space: 8 }) {
        if (this.editorMode === 'place') {
          Button('确认放置')
            .height(32).fontSize(13)
            .backgroundColor('#8aaa6a').fontColor('#0a0a1a')
            .onClick(() => { this.onConfirm(); })
        }

        Button('删除')
          .height(32).fontSize(13)
          .backgroundColor('#ff6b6b44').fontColor('#ff6b6b')
          .borderColor('#ff6b6b').borderWidth(1)
          .onClick(() => { this.onDelete(); })

        Button('取消')
          .height(32).fontSize(13)
          .backgroundColor('#1a1a2e').fontColor('#8a8a9a')
          .onClick(() => { this.onCancel(); })
      }
    }
    .padding(14)
    .backgroundColor('#E60f0f1f')
    .borderRadius(12)
    .border({ width: 1, color: '#d4b67888', style: BorderStyle.Solid, radius: 12 })
  }
}
