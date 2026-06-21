import { router } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  @State title: string = 'ArTree';
  @State subtitle: string = 'Beauty';
  @State devOpen: boolean = false;

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 135,
          colors: [['#0a0a1a', 0], ['#12122a', 0.5], ['#0c0c1e', 1]]
        })

      Column({ space: 16 }) {
        Column({ space: 6 }) {
          Text(this.title)
            .fontSize(80)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f5f1e6')
            .letterSpacing(16)

          Text(this.subtitle)
            .fontSize(18)
            .fontColor('#8a8a9a')
            .letterSpacing(6)
            .fontStyle(FontStyle.Italic)
        }
        .margin({ bottom: 40 })

        Row() {
          Image($r('app.media.icon_flame'))
            .width(18).height(18)
            .fillColor('#d4b678')
          Text('Western Hall')
            .fontSize(13)
            .fontColor('#b9a57a')
            .letterSpacing(4)
        }
        .margin({ bottom: 4 })

        Button({ type: ButtonType.Capsule }) {
          Column({ space: 4 }) {
            Text('David Gallery')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0a0a1a')
              .letterSpacing(4)
            Text('18 masterpieces')
              .fontSize(11)
              .fontColor('#3a3a4a')
              .letterSpacing(1)
          }
          .padding({ top: 8, bottom: 8 })
        }
        .width(340)
        .height(72)
        .backgroundColor('#d4b678')
        .borderRadius(14)
        .onClick(() => {
          router.pushUrl({ url: 'pages/DavidScene' });
        })

        Row({ space: 8 }) {
          Image($r('app.media.icon_flame'))
            .width(18).height(18)
            .fillColor('#6a9a6a')
          Text('Chinese Hall')
            .fontSize(13)
            .fontColor('#8aaa8a')
            .letterSpacing(4)
        }
        .margin({ top: 20, bottom: 4 })

        Button({ type: ButtonType.Capsule }) {
          Column({ space: 4 }) {
            Text('Chinese Gallery')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0a0a1a')
              .letterSpacing(4)
            Text('12 paintings')
              .fontSize(11)
              .fontColor('#3a4a3a')
              .letterSpacing(1)
          }
          .padding({ top: 8, bottom: 8 })
        }
        .width(340)
        .height(72)
        .backgroundColor('#8aaa6a')
        .borderColor('#889966')
        .borderWidth(1)
        .borderRadius(14)
        .enabled(true)
        .onClick(() => {
          router.pushUrl({ url: 'pages/ChineseGalleryScene' });
        })

        Button({ type: ButtonType.Capsule }) {
          Column({ space: 4 }) {
            Text('3DGS Pilot')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0a0a1a')
              .letterSpacing(4)
            Text('Spatial Recon entry')
              .fontSize(11)
              .fontColor('#314131')
              .letterSpacing(1)
          }
          .padding({ top: 8, bottom: 8 })
        }
        .width(340)
        .height(72)
        .backgroundColor('#8ac58a')
        .borderColor('#5a8a5a')
        .borderWidth(1)
        .borderRadius(14)
        .enabled(true)
        .onClick(() => {
          router.pushUrl({ url: 'pages/SpatialReconPilot' });
        })

        Column() {
          Row({ space: 6 }) {
            Divider()
              .strokeWidth(1)
              .color('#333344')
              .width(40)
            Text(this.devOpen ? 'Dev options' : 'Dev options')
              .fontSize(11)
              .fontColor('#4a4a5a')
              .letterSpacing(2)
            Divider()
              .strokeWidth(1)
              .color('#333344')
              .width(40)
          }
          .onClick(() => {
            this.devOpen = !this.devOpen;
          })
          .margin({ top: 32 })
          .padding({ top: 8, bottom: 8 })

          if (this.devOpen) {
            Column({ space: 10 }) {
              Button('Three.js WebView', { type: ButtonType.Capsule })
                .width(240).height(36).fontSize(13)
                .fontColor('#8a8a9a').backgroundColor('#1a1a2e')
                .borderColor('#4a4a5a').borderWidth(1)
                .onClick(() => {
                  router.pushUrl({ url: 'pages/ThreeJsHost' });
                })

              Button('3DGS Pilot', { type: ButtonType.Capsule })
                .width(240).height(36).fontSize(13)
                .fontColor('#8aaa8a').backgroundColor('#15251a')
                .borderColor('#5a8a5a').borderWidth(1)
                .onClick(() => {
                  router.pushUrl({ url: 'pages/SpatialReconPilot' });
                })

              Button('White Cube Gallery', { type: ButtonType.Capsule })
                .width(240).height(36).fontSize(13)
                .fontColor('#8a8a9a').backgroundColor('#1a1a2e')
                .borderColor('#4a4a5a').borderWidth(1)
                .onClick(() => {
                  router.pushUrl({ url: 'pages/GalleryScene' });
                })

              Button('Orbit Camera Test', { type: ButtonType.Capsule })
                .width(240).height(36).fontSize(13)
                .fontColor('#8a8a9a').backgroundColor('#1a1a2e')
                .borderColor('#4a4a5a').borderWidth(1)
                .onClick(() => {
                  router.pushUrl({ url: 'pages/GameScene' });
                })
            }
          }
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Text('v1.0')
        .fontSize(11)
        .fontColor('#3a3a4a')
        .position({ x: '50%', y: '96%' })
        .markAnchor({ x: 60, y: 0 })
    }
    .width('100%')
    .height('100%')
  }
}
