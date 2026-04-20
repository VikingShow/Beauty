import { router } from '@kit.ArkUI';

@Entry
@Component
struct GameScene {
  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')

      Component3D({ scene: $rawfile('gltf/DamagedHelmet/glTF/DamagedHelmet.gltf') })
        .width('100%')
        .height('100%')

      Row({ space: 12 }) {
        Button('← 返回')
          .fontSize(14)
          .height(36)
          .backgroundColor('#1a1a2e88')
          .fontColor('#ffffff')
          .onClick(() => {
            router.back();
          })

        Text('Phase 0 · Hello 3D')
          .fontSize(14)
          .fontColor('#d4b678')
          .margin({ left: 12 })
      }
      .position({ x: 20, y: 20 })
    }
    .width('100%')
    .height('100%')
  }
}
