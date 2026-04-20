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
import { FirstPersonCameraController } from '../controllers/FirstPersonCameraController';
import { GALLERY_WAYPOINTS, Waypoint } from '../scenes/Waypoint';
import { Minimap } from '../components/Minimap';

const DOMAIN = 0x0101;
const GALLERY_WORLD_RADIUS: number = 5.5;

@Entry
@Component
struct GalleryScene {
  @State private sceneReady: boolean = false;
  @State private errorMsg: string = '';
  @State private currentWpId: string = GALLERY_WAYPOINTS[0].id;
  @State private playerX: number = GALLERY_WAYPOINTS[0].position.x;
  @State private playerZ: number = GALLERY_WAYPOINTS[0].position.z;
  @State private playerYaw: number = GALLERY_WAYPOINTS[0].yaw;

  private sceneInstance: Scene | undefined = undefined;
  private controller: FirstPersonCameraController = new FirstPersonCameraController(GALLERY_WAYPOINTS[0]);

  async aboutToAppear(): Promise<void> {
    this.controller.setOnUpdate(() => {
      this.playerX = this.controller.getPositionX();
      this.playerZ = this.controller.getPositionZ();
      this.playerYaw = this.controller.getYaw();
    });

    try {
      const scene: Scene = await Scene.load(
        $rawfile('gltf/gallery/scene.gltf')
      );

      const factory: SceneResourceFactory = scene.getResourceFactory();

      const camParams: SceneNodeParameters = { name: 'fpCamera' };
      const cam: Camera = await factory.createCamera(camParams);
      cam.enabled = true;
      cam.fov = 70 * Math.PI / 180;
      cam.clearColor = { r: 0.04, g: 0.04, b: 0.10, a: 1.0 };
      this.controller.attach(cam);

      const lightParams: SceneNodeParameters = { name: 'fpLight' };
      await factory.createLight(lightParams, LightType.DIRECTIONAL);

      this.sceneInstance = scene;
      this.sceneReady = true;
    } catch (e) {
      const err = e as BusinessError;
      this.errorMsg = err.message ?? JSON.stringify(e);
      hilog.error(DOMAIN, 'GalleryScene', 'init failed: %{public}s', JSON.stringify(e));
    }
  }

  aboutToDisappear(): void {
    this.controller.detach();
  }

  private teleport(wp: Waypoint): void {
    this.controller.teleportTo(wp);
    this.currentWpId = wp.id;
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
            PanGesture({ fingers: 1 })
              .onActionStart(() => {
                this.controller.onPanStart();
              })
              .onActionUpdate((e: GestureEvent) => {
                this.controller.onPanUpdate(e.offsetX, e.offsetY);
              })
              .onActionEnd(() => {
                this.controller.onPanEnd();
              })
          )
      }

      if (this.errorMsg !== '') {
        Text('加载失败: ' + this.errorMsg)
          .fontColor('#ff6b6b')
          .fontSize(14)
          .position({ x: 20, y: 60 })
      }

      // 顶部栏
      Row({ space: 12 }) {
        Button('← 返回')
          .fontSize(14)
          .height(36)
          .backgroundColor('#1a1a2e88')
          .fontColor('#ffffff')
          .onClick(() => {
            router.back();
          })

        Text('Phase 1C · 圆形画廊  |  拖动转视角 · 点小地图或下方按钮切换')
          .fontSize(14)
          .fontColor('#d4b678')
          .margin({ left: 12 })
      }
      .position({ x: 20, y: 20 })

      // 右上角小地图
      Minimap({
        waypoints: GALLERY_WAYPOINTS,
        currentWaypointId: this.currentWpId,
        playerX: this.playerX,
        playerZ: this.playerZ,
        playerYaw: this.playerYaw,
        worldRadius: GALLERY_WORLD_RADIUS,
        onWaypointTap: (wp: Waypoint) => {
          this.teleport(wp);
        }
      })
        .position({ x: '100%', y: 20 })
        .markAnchor({ x: 200, y: 0 })

      // 底部航点切换条
      Row({ space: 12 }) {
        ForEach(GALLERY_WAYPOINTS, (wp: Waypoint) => {
          Button(wp.name, { type: ButtonType.Capsule })
            .height(40)
            .fontSize(14)
            .fontColor(this.currentWpId === wp.id ? '#0a0a1a' : '#d4b678')
            .backgroundColor(this.currentWpId === wp.id ? '#d4b678' : '#1a1a2e99')
            .borderColor('#d4b678')
            .borderWidth(1)
            .padding({ left: 18, right: 18 })
            .onClick(() => {
              this.teleport(wp);
            })
        }, (wp: Waypoint) => wp.id)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .position({ x: 0, y: '88%' })
    }
    .width('100%')
    .height('100%')
  }
}
