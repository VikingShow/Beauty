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
import { nearestExhibitId } from '../scenes/Exhibits';
import { clueForExhibit, isCollected, TOTAL_CLUE_COUNT, Clue } from '../scenes/Clues';
import { Minimap } from '../components/Minimap';
import { Joystick } from '../components/Joystick';
import { ExhibitCard } from '../components/ExhibitCard';
import { ObservationModal } from '../components/ObservationModal';

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
  @State private currentExhibitId: string = '';
  @State private loadingOpacity: number = 1;     // 加载覆盖层不透明度（1→0 淡出）
  @State private sceneOpacity: number = 0;       // 3D 场景不透明度（0→1 淡入）
  @State private loadingDots: string = '';       // "第一关 · David 加载中" 后面的跳动省略号
  private dotsTimer: number | undefined = undefined;

  // —— 根特悬案（3A）——
  @State private discoveredClueIds: Array<string> = [];
  @State private modalVisible: boolean = false;
  @State private modalExhibitId: string = '';
  @State private modalAlreadyCollected: boolean = false;
  // 开场"午夜钟声"覆盖层
  @State private introVisible: boolean = false;
  @State private introOpacity: number = 0;
  @State private introShown: boolean = false;

  private sceneInstance: Scene | undefined = undefined;
  private controller: FirstPersonCameraController = new FirstPersonCameraController(DAVID_WAYPOINTS[0]);

  async aboutToAppear(): Promise<void> {
    // 启动加载提示的省略号动画
    this.startDotsAnimation();

    this.controller.setOnUpdate(() => {
      this.playerX = this.controller.getPositionX();
      this.playerZ = this.controller.getPositionZ();
      this.playerYaw = this.controller.getYaw();
      const next: string = nearestExhibitId(this.playerX, this.playerZ);
      if (next !== this.currentExhibitId) {
        this.currentExhibitId = next;
      }
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
      // 场景就绪：3D 立即淡入，加载层延后 120ms 淡出，形成交叉过渡
      animateTo({ duration: 500, curve: Curve.EaseInOut }, () => {
        this.sceneOpacity = 1;
      });
      setTimeout(() => {
        animateTo({ duration: 500, curve: Curve.EaseInOut }, () => {
          this.loadingOpacity = 0;
        });
      }, 120);
      this.stopDotsAnimation();
      // 加载结束后播放一次"午夜钟声"开场独白
      setTimeout(() => {
        this.playIntro();
      }, 900);
    } catch (e) {
      const err = e as BusinessError;
      this.errorMsg = err.message ?? JSON.stringify(e);
      hilog.error(DOMAIN, 'DavidScene', 'init failed: %{public}s', JSON.stringify(e));
      this.stopDotsAnimation();
    }
  }

  aboutToDisappear(): void {
    this.controller.detach();
    this.stopDotsAnimation();
  }

  private startDotsAnimation(): void {
    const cycle: string[] = ['', '·', '··', '···'];
    let i: number = 0;
    const tick = (): void => {
      this.loadingDots = cycle[i % cycle.length];
      i++;
      this.dotsTimer = setTimeout(tick, 350);
    };
    tick();
  }

  private stopDotsAnimation(): void {
    if (this.dotsTimer !== undefined) {
      clearTimeout(this.dotsTimer);
      this.dotsTimer = undefined;
    }
  }

  private teleport(wp: Waypoint): void {
    this.controller.teleportTo(wp);
    this.currentWpId = wp.id;
  }

  // —— 3A：观察模态 & 开场钟声 ——

  private playIntro(): void {
    if (this.introShown) return;
    this.introShown = true;
    this.introVisible = true;
    animateTo({ duration: 900, curve: Curve.EaseIn }, () => {
      this.introOpacity = 1;
    });
    setTimeout(() => {
      animateTo({ duration: 900, curve: Curve.EaseOut }, () => {
        this.introOpacity = 0;
      });
      setTimeout(() => {
        this.introVisible = false;
      }, 900);
    }, 3200);
  }

  private getClueState(exhibitId: string): string {
    const c: Clue | undefined = clueForExhibit(exhibitId);
    if (c === undefined) return 'none';
    if (isCollected(c.id, this.discoveredClueIds)) return 'collected';
    return 'available';
  }

  private openObservation(): void {
    if (this.currentExhibitId === '') return;
    const c: Clue | undefined = clueForExhibit(this.currentExhibitId);
    const collected: boolean = c !== undefined && isCollected(c.id, this.discoveredClueIds);
    this.modalExhibitId = this.currentExhibitId;
    this.modalAlreadyCollected = collected;
    this.modalVisible = true;
  }

  private collectClue(clueId: string): void {
    if (isCollected(clueId, this.discoveredClueIds)) return;
    this.discoveredClueIds = this.discoveredClueIds.concat([clueId]);
    this.modalAlreadyCollected = true;
  }

  private closeObservation(): void {
    this.modalVisible = false;
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
          .opacity(this.sceneOpacity)
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

      // 顶部居中展品介绍卡（走近画作自动显示）
      ExhibitCard({
        exhibitId: this.currentExhibitId,
        clueState: this.getClueState(this.currentExhibitId),
        onObserve: () => {
          this.openObservation();
        }
      })
        .position({ x: '50%', y: 70 })
        .markAnchor({ x: 260, y: 0 })

      // 右侧 · 线索计数器
      Row({ space: 8 }) {
        Image($r('app.media.icon_book'))
          .width(16)
          .height(16)
          .fillColor('#d4b678')
        Text(`${this.discoveredClueIds.length} / ${TOTAL_CLUE_COUNT}`)
          .fontSize(14)
          .fontColor('#d4b678')
          .fontWeight(FontWeight.Medium)
      }
      .padding({ left: 14, right: 14, top: 7, bottom: 7 })
      .backgroundColor('#1a1a2eE6')
      .borderColor('#d4b67888')
      .borderWidth(1)
      .borderRadius(18)
      .position({ x: '100%', y: 188 })
      .markAnchor({ x: 82, y: 0 })

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

      // 加载覆盖层：放在最后，覆盖所有 UI chrome，淡出后才露出场景+按钮
      if (this.loadingOpacity > 0) {
        Column({ space: 28 }) {
          Text('第一关')
            .fontSize(14)
            .fontColor('#8a8a9a')
            .letterSpacing(6)

          Text('David')
            .fontSize(56)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f5e6c8')
            .letterSpacing(10)

          LoadingProgress()
            .width(48)
            .height(48)
            .color('#d4b678')
            .margin({ top: 28 })

          Text(`加载中${this.loadingDots}`)
            .fontSize(15)
            .fontColor('#d4b67899')
            .letterSpacing(2)
            .width(140)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .linearGradient({
          angle: 135,
          colors: [['#0a0a1a', 0], ['#1a1a2e', 0.5], ['#0f0f1f', 1]]
        })
        .opacity(this.loadingOpacity)
        .hitTestBehavior(
          this.loadingOpacity > 0.02 ? HitTestMode.Block : HitTestMode.Transparent
        )
      }

      // 开场 · 午夜钟声独白（一次性，不阻挡操作）
      if (this.introVisible) {
        Column({ space: 14 }) {
          Image($r('app.media.icon_clock'))
            .width(44)
            .height(44)
            .fillColor('#d4b678')

          Text('午 夜 钟 声')
            .fontSize(22)
            .fontColor('#f5e6c8')
            .letterSpacing(10)
            .fontWeight(FontWeight.Bold)
            .margin({ top: 6 })

          Text('画中之物，开始低语。')
            .fontSize(14)
            .fontColor('#d4b678CC')
            .letterSpacing(4)
            .margin({ top: 6 })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 180 })
        .opacity(this.introOpacity)
        .hitTestBehavior(HitTestMode.Transparent)
      }

      // 观察模态：最顶层
      ObservationModal({
        visible: this.modalVisible,
        exhibitId: this.modalExhibitId,
        alreadyCollected: this.modalAlreadyCollected,
        onClose: () => {
          this.closeObservation();
        },
        onCollect: (clueId: string) => {
          this.collectClue(clueId);
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
