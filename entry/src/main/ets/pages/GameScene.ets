import { router } from '@kit.ArkUI';
import { Scene } from '@kit.ArkGraphics3D';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0100;

@Entry
@Component
struct GameScene {
  @State loadError: string = '';
  @State rotationY: number = 0;

  private scene: Promise<Scene> = Scene.load(
    $rawfile('gltf/DamagedHelmet/glTF/DamagedHelmet.gltf')
  );

  aboutToAppear(): void {
    this.scene
      .then(() => {
        hilog.info(DOMAIN, 'GameScene', 'glTF scene loaded');
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, 'GameScene', 'scene load failed: %{public}s', JSON.stringify(err));
        this.loadError = 'glTF 加载失败: ' + err.message;
      });
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')

      if (this.loadError === '') {
        Component3D({ scene: this.scene })
          .width('100%')
          .height('100%')
          .gesture(
            PanGesture({ fingers: 1 })
              .onActionUpdate((event: GestureEvent) => {
                this.rotationY = (event.offsetX ?? 0) * 0.5;
              })
          )
      } else {
        Column({ space: 16 }) {
          Text('⚠️ 3D 场景加载失败')
            .fontSize(24)
            .fontColor('#ff6b6b')
          Text(this.loadError)
            .fontSize(14)
            .fontColor('#cccccc')
            .textAlign(TextAlign.Center)
            .padding(24)
          Text('请确认已将 DamagedHelmet 放入:\nentry/src/main/resources/rawfile/gltf/DamagedHelmet/')
            .fontSize(12)
            .fontColor('#888888')
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }

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
