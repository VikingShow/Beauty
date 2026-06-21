import { router } from '@kit.ArkUI';

@Entry
@Component
struct SpatialReconPilot {
  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#07130f')

      Column({ space: 18 }) {
        Text('3DGS Pilot')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor('#cfe8d2')

        Text('This page reserves the integration point for HarmonyOS Spatial Recon 3DGS.')
          .fontSize(14)
          .fontColor('#8ea494')
          .textAlign(TextAlign.Center)

        Column({ space: 10 }) {
          Text('Target')
            .fontSize(16)
            .fontColor('#d4b678')
            .fontWeight(FontWeight.Medium)
          Text('Chinese Hall / xiao_xiang')
            .fontSize(14)
            .fontColor('#dfe7df')
          Text('Fallback: fuchun_shanju')
            .fontSize(14)
            .fontColor('#aebbb0')
        }
        .padding(18)
        .backgroundColor('#102018')
        .borderRadius(12)

        Column({ space: 10 }) {
          Text('Status')
            .fontSize(16)
            .fontColor('#d4b678')
            .fontWeight(FontWeight.Medium)
          Text('1. The page is wired into the main menu')
            .fontSize(14)
            .fontColor('#dfe7df')
          Text('2. Native 3DGS SDK hooks are pending')
            .fontSize(14)
            .fontColor('#dfe7df')
          Text('3. Load, render, exit, and fallback will land here next')
            .fontSize(14)
            .fontColor('#dfe7df')
        }
        .padding(18)
        .backgroundColor('#102018')
        .borderRadius(12)

        Button('Back')
          .width(180)
          .height(40)
          .fontSize(14)
          .backgroundColor('#d4b678')
          .fontColor('#0a0a0f')
          .onClick(() => {
            router.back();
          })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 28, right: 28, top: 36, bottom: 36 })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }
}
