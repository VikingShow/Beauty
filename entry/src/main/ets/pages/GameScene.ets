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

const DOMAIN = 0x0100;
const PITCH_LIMIT = 1.47;

@Entry
@Component
struct GameScene {
  @State private sceneReady: boolean = false;
  @State private errorMsg: string = '';

  private sceneInstance: Scene | undefined = undefined;
  private camera: Camera | undefined = undefined;

  private yaw: number = 0;
  private pitch: number = 0;
  private distance: number = 5;

  private yawStart: number = 0;
  private pitchStart: number = 0;
  private distanceStart: number = 5;

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
      this.camera = cam;

      const lightParams: SceneNodeParameters = { name: 'mainLight' };
      await factory.createLight(lightParams, LightType.DIRECTIONAL);

      this.applyCamera();

      this.sceneInstance = scene;
      this.sceneReady = true;
    } catch (e) {
      const err = e as BusinessError;
      this.errorMsg = err.message ?? JSON.stringify(e);
      hilog.error(DOMAIN, 'GameScene', 'scene init failed: %{public}s', JSON.stringify(e));
    }
  }

  private applyCamera(): void {
    if (this.camera === undefined) {
      return;
    }
    const yaw: number = this.yaw;
    const pitch: number = Math.max(-PITCH_LIMIT, Math.min(PITCH_LIMIT, this.pitch));
    const d: number = this.distance;

    this.camera.position.x = d * Math.cos(pitch) * Math.sin(yaw);
    this.camera.position.y = d * Math.sin(pitch);
    this.camera.position.z = d * Math.cos(pitch) * Math.cos(yaw);

    const hy: number = yaw / 2;
    const hp: number = pitch / 2;
    const cy: number = Math.cos(hy);
    const sy: number = Math.sin(hy);
    const cp: number = Math.cos(hp);
    const sp: number = Math.sin(hp);

    this.camera.rotation = {
      x: -cy * sp,
      y: sy * cp,
      z: sy * sp,
      w: cy * cp
    };
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
                  this.yawStart = this.yaw;
                  this.pitchStart = this.pitch;
                })
                .onActionUpdate((e: GestureEvent) => {
                  this.yaw = this.yawStart - e.offsetX * 0.01;
                  this.pitch = this.pitchStart + e.offsetY * 0.01;
                  this.applyCamera();
                }),
              PinchGesture({ fingers: 2 })
                .onActionStart(() => {
                  this.distanceStart = this.distance;
                })
                .onActionUpdate((e: GestureEvent) => {
                  const next: number = this.distanceStart / e.scale;
                  this.distance = Math.max(2, Math.min(15, next));
                  this.applyCamera();
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

        Text('Phase 0 · Hello 3D  |  拖动旋转 · 双指缩放')
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
