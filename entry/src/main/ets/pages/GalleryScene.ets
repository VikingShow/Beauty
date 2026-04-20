import { router } from '@kit.ArkUI';
import {
  Scene,
  SceneResourceFactory,
  Camera,
  Light,
  LightType,
  SceneNodeParameters
} from '@kit.ArkGraphics3D';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { FirstPersonCameraController } from '../controllers/FirstPersonCameraController';
import { GALLERY_LAYOUT, GALLERY_WAYPOINTS, Waypoint } from '../scenes/Waypoint';
import { Minimap } from '../components/Minimap';

const DOMAIN = 0x0101;

interface RGBA {
  r: number;
  g: number;
  b: number;
  a: number;
}

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
      // 较暗的环境色让方向光的明暗对比更明显
      cam.clearColor = { r: 0.18, g: 0.20, b: 0.24, a: 1.0 };
      this.controller.attach(cam);

      // 主光（顶部偏前下方，强）+ 暖色补光（侧面，弱）+ 冷色环境补光
      const warmWhite: RGBA = { r: 1.0, g: 0.96, b: 0.88, a: 1.0 };
      const coolFill: RGBA = { r: 0.55, g: 0.65, b: 0.85, a: 1.0 };

      // 主光：顶部稍偏南方向（quat 绕 X -75°，让光线斜照而非纯垂直，制造立体阴影感）
      const lightKeyParams: SceneNodeParameters = { name: 'lightKey' };
      const lightKey: Light = await factory.createLight(lightKeyParams, LightType.DIRECTIONAL);
      lightKey.enabled = true;
      lightKey.color = warmWhite;
      lightKey.intensity = 8.0;
      lightKey.rotation = { x: -0.6088, y: 0, z: 0, w: 0.7934 };

      // 冷色补光：从北侧反向照过来，模拟天窗冷光
      const lightFillParams: SceneNodeParameters = { name: 'lightFill' };
      const lightFill: Light = await factory.createLight(lightFillParams, LightType.DIRECTIONAL);
      lightFill.enabled = true;
      lightFill.color = coolFill;
      lightFill.intensity = 3.0;
      // 旋转 180° 绕 Y：朝 +Z 方向
      lightFill.rotation = { x: 0, y: 1, z: 0, w: 0 };

      // 侧面暖色补光：从东侧斜下来
      const lightSideParams: SceneNodeParameters = { name: 'lightSide' };
      const lightSide: Light = await factory.createLight(lightSideParams, LightType.DIRECTIONAL);
      lightSide.enabled = true;
      lightSide.color = warmWhite;
      lightSide.intensity = 2.5;
      // 绕 Y 60° + 绕 X -20°：侧前方斜上
      lightSide.rotation = { x: -0.166, y: 0.487, z: 0.094, w: 0.853 };

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
        layout: GALLERY_LAYOUT,
        currentWaypointId: this.currentWpId,
        playerX: this.playerX,
        playerZ: this.playerZ,
        playerYaw: this.playerYaw,
        onWaypointTap: (wp: Waypoint) => {
          this.teleport(wp);
        }
      })
        .position({ x: '100%', y: 20 })
        .markAnchor({ x: 240, y: 0 })

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
