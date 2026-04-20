import { router } from '@kit.ArkUI';
import {
  Scene,
  SceneResourceFactory,
  Camera,
  LightType,
  SceneNodeParameters
} from '@kit.ArkGraphics3D';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { OrbitCameraController } from '../controllers/OrbitCameraController';

const DOMAIN = 0x0100;

@Entry
@Component
struct GameScene {
  @State private sceneReady: boolean = false;
  @State private errorMsg: string = '';

  private sceneInstance: Scene | undefined = undefined;
  private controller: OrbitCameraController = new OrbitCameraController(5);

  async aboutToAppear(): Promise<void> {
    try {
      const scene: Scene = await Scene.load(
        $rawfile('gltf/DamagedHelmet/glTF/DamagedHelmet.gltf')
      );

      const factory: SceneResourceFactory = scene.getResourceFactory();

      const camParams: SceneNodeParameters = { name: 'mainCamera' };
      const cam: Camera = await factory.createCamera(camParams);
      cam.enabled = true;
      cam.fov = 60 * Math.PI / 180;
      cam.clearColor = { r: 0.04, g: 0.04, b: 0.10, a: 1.0 };
      this.controller.attach(cam);

      const lightParams: SceneNodeParameters = { name: 'mainLight' };
      await factory.createLight(lightParams, LightType.DIRECTIONAL);

      this.sceneInstance = scene;
      this.sceneReady = true;
    } catch (e) {
      const err = e as BusinessError;
      this.errorMsg = err.message ?? JSON.stringify(e);
      hilog.error(DOMAIN, 'GameScene', 'scene init failed: %{public}s', JSON.stringify(e));
    }
  }

  aboutToDisappear(): void {
    this.controller.detach();
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#0a0a1a')

      if (this.sceneReady && this.sceneInstance !== undefined) {
        Component3D({ scene: this.sceneInstance })
          .width('100%')
          .height('100%')
          .backgroundColor('#0a0a1a')
          .gesture(
            GestureGroup(GestureMode.Parallel,
              PanGesture({ fingers: 1 })
                .onActionStart(() => {
                  this.controller.onPanStart();
                })
                .onActionUpdate((e: GestureEvent) => {
                  this.controller.onPanUpdate(e.offsetX, e.offsetY);
                })
                .onActionEnd(() => {
                  this.controller.onPanEnd();
                }),
              PinchGesture({ fingers: 2 })
                .onActionStart(() => {
                  this.controller.onPinchStart();
                })
                .onActionUpdate((e: GestureEvent) => {
                  this.controller.onPinchUpdate(e.scale);
                })
                .onActionEnd(() => {
                  this.controller.onPinchEnd();
                })
            )
          )
      }

      if (this.errorMsg !== '') {
        Text('加载失败: ' + this.errorMsg)
          .fontColor('#ff6b6b')
          .fontSize(14)
          .position({ x: 20, y: 60 })
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

        Text('Phase 1A · Orbit Camera')
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
