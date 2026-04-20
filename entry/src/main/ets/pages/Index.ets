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

      Column({ space: 24 }) {
        Text(this.title)
          .fontSize(72)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f5f1e6')
          .letterSpacing(8)

        Text(this.subtitle)
          .fontSize(20)
          .fontColor('#8a8a9a')
          .letterSpacing(4)
          .margin({ bottom: 40 })

        Button('开始巡夜', { type: ButtonType.Capsule })
          .width(240)
          .height(56)
          .fontSize(20)
          .fontColor('#0a0a1a')
          .backgroundColor('#d4b678')
          .onClick(() => {
            router.pushUrl({ url: 'pages/GameScene' });
          })

        Button('3D 环境测试', { type: ButtonType.Capsule })
          .width(240)
          .height(48)
          .fontSize(16)
          .fontColor('#d4b678')
          .backgroundColor('#1a1a2e')
          .borderColor('#d4b678')
          .borderWidth(1)
          .onClick(() => {
            router.pushUrl({ url: 'pages/GameScene', params: { mode: 'test' } });
          })

        Text('v0.1 · Phase 0')
          .fontSize(12)
          .fontColor('#4a4a5a')
          .margin({ top: 60 })
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
