@Component
export struct PropertyPanel {
  @Prop name: string = '';
  @Prop posX: number = 0;
  @Prop posY: number = 0;
  @Prop posZ: number = 0;
  @Prop rotY: number = 0;
  @Prop scaleVal: number = 1.0;
  onNudge: (dx: number, dy: number, dz: number) => void = () => {};
  onRotate: (deg: number) => void = () => {};
  onScale: (factor: number) => void = () => {};
  onConfirm: () => void = () => {};
  onDelete: () => void = () => {};
  onCancel: () => void = () => {};

  build() {
    Column({ space: 10 }) {
      Text(this.name)
        .fontSize(14)
        .fontColor('#f5e6c8')
        .fontWeight(FontWeight.Medium)
        .maxLines(1)

      Column({ space: 6 }) {
        Row({ space: 4 }) {
          Text('X')
            .fontSize(10)
            .fontColor('#8a8a9a')
            .width(14)
          Slider({ value: this.posX, min: -50, max: 50, step: 0.1 })
            .width(80)
            .height(20)
            .blockColor('#d4b678')
            .trackColor('#2a2a3a')
            .selectedColor('#d4b67844')
            .onChange((value: number) => {
              this.onNudge(value - this.posX, 0, 0);
            })
          Text(this.posX.toFixed(1))
            .fontSize(9)
            .fontColor('#d4b678')
            .width(28)
        }

        Row({ space: 4 }) {
          Text('高度')
            .fontSize(10)
            .fontColor('#8a8a9a')
            .width(28)
          Slider({ value: this.posY, min: 0, max: 10, step: 0.1 })
            .width(80)
            .height(20)
            .blockColor('#d4b678')
            .trackColor('#2a2a3a')
            .selectedColor('#d4b67844')
            .onChange((value: number) => {
              this.onNudge(0, value - this.posY, 0);
            })
          Text(this.posY.toFixed(1))
            .fontSize(9)
            .fontColor('#d4b678')
            .width(28)
        }

        Row({ space: 4 }) {
          Text('Z')
            .fontSize(10)
            .fontColor('#8a8a9a')
            .width(14)
          Slider({ value: this.posZ, min: -50, max: 50, step: 0.1 })
            .width(80)
            .height(20)
            .blockColor('#d4b678')
            .trackColor('#2a2a3a')
            .selectedColor('#d4b67844')
            .onChange((value: number) => {
              this.onNudge(0, 0, value - this.posZ);
            })
          Text(this.posZ.toFixed(1))
            .fontSize(9)
            .fontColor('#d4b678')
            .width(28)
        }
      }

      Column({ space: 6 }) {
        Row({ space: 4 }) {
          Text('旋转')
            .fontSize(10)
            .fontColor('#8a8a9a')
            .width(28)
          Slider({ value: this.rotY, min: -180, max: 180, step: 1 })
            .width(80)
            .height(20)
            .blockColor('#d4b678')
            .trackColor('#2a2a3a')
            .selectedColor('#d4b67844')
            .onChange((value: number) => {
              this.onRotate(value - this.rotY);
            })
          Text(this.rotY.toFixed(0) + '°')
            .fontSize(9)
            .fontColor('#d4b678')
            .width(28)
        }

        Row({ space: 4 }) {
          Text('缩放')
            .fontSize(10)
            .fontColor('#8a8a9a')
            .width(28)
          Slider({ value: this.scaleVal, min: 0.1, max: 5, step: 0.1 })
            .width(80)
            .height(20)
            .blockColor('#d4b678')
            .trackColor('#2a2a3a')
            .selectedColor('#d4b67844')
            .onChange((value: number) => {
              if (this.scaleVal > 0.01) {
                this.onScale(value / this.scaleVal);
              }
            })
          Text(this.scaleVal.toFixed(1) + 'x')
            .fontSize(9)
            .fontColor('#d4b678')
            .width(28)
        }
      }

      Row({ space: 6 }) {
        Button('确认')
          .height(28).fontSize(12)
          .backgroundColor('#8aaa6a').fontColor('#0a0a1a')
          .onClick(() => { this.onConfirm(); })

        Button('删除')
          .height(28).fontSize(12)
          .backgroundColor('#ff6b6b44').fontColor('#ff6b6b')
          .borderColor('#ff6b6b').borderWidth(1)
          .onClick(() => { this.onDelete(); })

        Button('取消')
          .height(28).fontSize(12)
          .backgroundColor('#1a1a2e').fontColor('#8a8a9a')
          .onClick(() => { this.onCancel(); })
      }
    }
    .padding(12)
    .backgroundColor('#E60f0f1f')
    .borderRadius(10)
    .border({ width: 1, color: '#d4b67866', style: BorderStyle.Solid, radius: 10 })
  }
}
