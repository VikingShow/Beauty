import { router } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  @State title: string = '夜游艺术馆';
  @State subtitle: string = 'Night at the Gallery';

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 135,
          colors: [['#0a0a1a', 0], ['#1a1a2e', 0.5], ['#0f0f1f', 1]]
        })

      Column({ space: 20 }) {
        Text(this.title)
          .fontSize(72)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f5f1e6')
          .letterSpacing(8)

        Text(this.subtitle)
          .fontSize(20)
          .fontColor('#8a8a9a')
          .letterSpacing(4)
          .margin({ bottom: 36 })

        // 主关卡入口
        Button('第一关 · David', { type: ButtonType.Capsule })
          .width(280)
          .height(60)
          .fontSize(22)
          .fontColor('#0a0a1a')
          .backgroundColor('#d4b678')
          .onClick(() => {
            router.pushUrl({ url: 'pages/DavidScene' });
          })

        Text('— 测试场景 —')
          .fontSize(12)
          .fontColor('#5a5a6a')
          .margin({ top: 28, bottom: 4 })

        Button('布展模拟器（白立方）', { type: ButtonType.Capsule })
          .width(220)
          .height(40)
          .fontSize(14)
          .fontColor('#d4b678')
          .backgroundColor('#1a1a2e')
          .borderColor('#d4b678')
          .borderWidth(1)
          .onClick(() => {
            router.pushUrl({ url: 'pages/ExhibitionEditor' });
          })

        Button('展厅漫游（白盒）', { type: ButtonType.Capsule })
          .width(220)
          .height(40)
          .fontSize(14)
          .fontColor('#8a8a9a')
          .backgroundColor('#1a1a2e')
          .borderColor('#4a4a5a')
          .borderWidth(1)
          .onClick(() => {
            router.pushUrl({ url: 'pages/GalleryScene' });
          })

        Button('3D 轨道相机', { type: ButtonType.Capsule })
          .width(220)
          .height(40)
          .fontSize(14)
          .fontColor('#8a8a9a')
          .backgroundColor('#1a1a2e')
          .borderColor('#4a4a5a')
          .borderWidth(1)
          .onClick(() => {
            router.pushUrl({ url: 'pages/GameScene' });
          })

        Text('v0.3 · Phase 0 布展模拟器')
          .fontSize(12)
          .fontColor('#4a4a5a')
          .margin({ top: 40 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }
}
