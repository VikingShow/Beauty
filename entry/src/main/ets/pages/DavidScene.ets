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
import { AABB2, FirstPersonCameraController } from '../controllers/FirstPersonCameraController';
import { DAVID_LAYOUT, DAVID_WAYPOINTS, SceneFeature, Waypoint } from '../scenes/Waypoint';
import { Minimap } from '../components/Minimap';
import { Joystick } from '../components/Joystick';

const DOMAIN = 0x0102;

interface RGBA {
  r: number;
  g: number;
  b: number;
  a: number;
}

/**
 * 第一关 · David
 *
 * 资产：Art Gallery by Zeps3D (CC-BY 4.0)
 * 模型单位：厘米；场景内有雕像与树，玩家在其间巡游。
 */
@Entry
@Component
struct DavidScene {
  @State private sceneReady: boolean = false;
  @State private errorMsg: string = '';
  @State private currentWpId: string = DAVID_WAYPOINTS[0].id;
  @State private playerX: number = DAVID_WAYPOINTS[0].position.x;
  @State private playerZ: number = DAVID_WAYPOINTS[0].position.z;
  @State private playerYaw: number = DAVID_WAYPOINTS[0].yaw;

  private sceneInstance: Scene | undefined = undefined;
  private controller: FirstPersonCameraController = new FirstPersonCameraController(DAVID_WAYPOINTS[0]);

  async aboutToAppear(): Promise<void> {
    this.controller.setOnUpdate(() => {
      this.playerX = this.controller.getPositionX();
      this.playerZ = this.controller.getPositionZ();
      this.playerYaw = this.controller.getYaw();
    });

    // 设置可行区 + 碰撞障碍
    this.controller.setBounds(DAVID_LAYOUT.boundsMin, DAVID_LAYOUT.boundsMax);
    const solidColliders: AABB2[] = [];
    for (const f of DAVID_LAYOUT.features ?? []) {
      if (f.solid === true) {
        solidColliders.push({ minX: f.minX, maxX: f.maxX, minZ: f.minZ, maxZ: f.maxZ });
      }
    }
    this.controller.setColliders(solidColliders);

    try {
      hilog.info(DOMAIN, 'DavidScene', 'start loading David scene');
      const scene: Scene = await Scene.load(
        $rawfile('gltf/David/scene.gltf')
      );
      hilog.info(DOMAIN, 'DavidScene', 'scene loaded OK');

      const factory: SceneResourceFactory = scene.getResourceFactory();

      const camParams: SceneNodeParameters = { name: 'davidCamera' };
      const cam: Camera = await factory.createCamera(camParams);
      cam.enabled = true;
      cam.fov = 70 * Math.PI / 180;
      // 模型在厘米单位下较大，放宽近/远裁剪
      cam.nearPlane = 0.1;
      cam.farPlane = 100.0;
      // 亮天光色，抬高整体曝光
      cam.clearColor = { r: 0.72, g: 0.78, b: 0.85, a: 1.0 };
      this.controller.attach(cam);

      const warmWhite: RGBA = { r: 1.0, g: 0.96, b: 0.88, a: 1.0 };
      const coolFill: RGBA = { r: 0.7, g: 0.8, b: 0.95, a: 1.0 };
      const pureWhite: RGBA = { r: 1.0, g: 1.0, b: 1.0, a: 1.0 };

      // 主光：顶部稍斜下
      const lightKeyParams: SceneNodeParameters = { name: 'davidKey' };
      const lightKey: Light = await factory.createLight(lightKeyParams, LightType.DIRECTIONAL);
      lightKey.enabled = true;
      lightKey.color = warmWhite;
      lightKey.intensity = 14.0;
      lightKey.rotation = { x: -0.6088, y: 0, z: 0, w: 0.7934 };

      // 冷色反向补光
      const lightFillParams: SceneNodeParameters = { name: 'davidFill' };
      const lightFill: Light = await factory.createLight(lightFillParams, LightType.DIRECTIONAL);
      lightFill.enabled = true;
      lightFill.color = coolFill;
      lightFill.intensity = 6.0;
      lightFill.rotation = { x: 0, y: 1, z: 0, w: 0 };

      // 侧面暖色补光
      const lightSideParams: SceneNodeParameters = { name: 'davidSide' };
      const lightSide: Light = await factory.createLight(lightSideParams, LightType.DIRECTIONAL);
      lightSide.enabled = true;
      lightSide.color = warmWhite;
      lightSide.intensity = 5.0;
      lightSide.rotation = { x: -0.166, y: 0.487, z: 0.094, w: 0.853 };

      // 顶部纯白环境补光，模拟天窗漫射
      const lightTopParams: SceneNodeParameters = { name: 'davidTop' };
      const lightTop: Light = await factory.createLight(lightTopParams, LightType.DIRECTIONAL);
      lightTop.enabled = true;
      lightTop.color = pureWhite;
      lightTop.intensity = 8.0;
      lightTop.rotation = { x: -0.7071, y: 0, z: 0, w: 0.7071 };

      this.sceneInstance = scene;
      this.sceneReady = true;
    } catch (e) {
      const err = e as BusinessError;
      this.errorMsg = err.message ?? JSON.stringify(e);
      hilog.error(DOMAIN, 'DavidScene', 'init failed: %{public}s', JSON.stringify(e));
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

        Text('第一关 · David  |  拖动转视角 · 点小地图或下方按钮切换')
          .fontSize(14)
          .fontColor('#d4b678')
          .margin({ left: 12 })
      }
      .position({ x: 20, y: 20 })

      // 右上角小地图
      Minimap({
        waypoints: DAVID_WAYPOINTS,
        layout: DAVID_LAYOUT,
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

      // 左下角虚拟摇杆
      Joystick({
        onInput: (x: number, y: number) => {
          this.controller.setMoveInput(x, y);
        }
      })
        .position({ x: 32, y: '100%' })
        .markAnchor({ x: 0, y: 192 })

      // 底部航点切换条
      Row({ space: 12 }) {
        ForEach(DAVID_WAYPOINTS, (wp: Waypoint) => {
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
