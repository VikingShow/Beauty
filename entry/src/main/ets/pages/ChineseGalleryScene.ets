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
import { CHINESE_GALLERY_LAYOUT, CHINESE_GALLERY_WAYPOINTS, Waypoint } from '../scenes/Waypoint';
import { nearestChineseExhibitId, findChineseExhibit, Exhibit } from '../scenes/ChineseExhibits';
import { clueForExhibit, isCollected, TOTAL_CLUE_COUNT, Clue } from '../scenes/ChineseClues';
import { Minimap } from '../components/Minimap';
import { Joystick } from '../components/Joystick';
import { ExhibitCard } from '../components/ExhibitCard';
import { ObservationModal } from '../components/ObservationModal';
import { NotebookModal } from '../components/NotebookModal';
import { SpeechEngine } from '../utils/SpeechEngine';
import { BgmEngine } from '../utils/BgmEngine';
import { SettingsModal } from '../components/SettingsModal';

const DOMAIN = 0x0103;

interface RGBA {
  r: number;
  g: number;
  b: number;
  a: number;
}

/**
 * 中国馆 · 兰亭序之谜
 *
 * 三厅串联：A厅(山水之间) → B厅(人物与叙事) → C厅(文人写意)
 * 12幅传世名画 · 6条线索 · 寻找藏在《潇湘图》中的兰亭序真迹
 */
@Entry
@Component
struct ChineseGalleryScene {
  @State private sceneReady: boolean = false;
  @State private errorMsg: string = '';
  @State private currentWpId: string = CHINESE_GALLERY_WAYPOINTS[0].id;
  @State private playerX: number = CHINESE_GALLERY_WAYPOINTS[0].position.x;
  @State private playerZ: number = CHINESE_GALLERY_WAYPOINTS[0].position.z;
  @State private playerYaw: number = CHINESE_GALLERY_WAYPOINTS[0].yaw;
  @State private currentExhibitId: string = '';
  @State private loadingOpacity: number = 1;
  @State private sceneOpacity: number = 0;
  @State private loadingDots: string = '';
  private dotsTimer: number | undefined = undefined;

  @State private discoveredClueIds: Array<string> = [];
  @State private modalVisible: boolean = false;
  @State private modalExhibitId: string = '';
  @State private modalAlreadyCollected: boolean = false;
  @State private notebookVisible: boolean = false;
  @State private introVisible: boolean = false;
  @State private introOpacity: number = 0;
  @State private introShown: boolean = false;

  private sceneInstance: Scene | undefined = undefined;
  private controller: FirstPersonCameraController = new FirstPersonCameraController(CHINESE_GALLERY_WAYPOINTS[0]);
  private speech: SpeechEngine = SpeechEngine.getInstance();
  private bgm: BgmEngine = BgmEngine.getInstance();
  @State private settingsVisible: boolean = false;
  @State private voiceOn: boolean = true;
  @State private musicOn: boolean = false;

  async aboutToAppear(): Promise<void> {
    this.startDotsAnimation();

    this.controller.setOnUpdate(() => {
      this.playerX = this.controller.getPositionX();
      this.playerZ = this.controller.getPositionZ();
      this.playerYaw = this.controller.getYaw();
      const next: string = nearestChineseExhibitId(this.playerX, this.playerZ);
      if (next !== this.currentExhibitId) {
        this.currentExhibitId = next;
        if (next !== '') {
          const e: Exhibit | undefined = findChineseExhibit(next);
          if (e !== undefined) {
            this.speech.speak(e.titleZh + '。' + e.artist + '。' + e.description);
          }
        }
      }
    });

    this.controller.setBounds(CHINESE_GALLERY_LAYOUT.boundsMin, CHINESE_GALLERY_LAYOUT.boundsMax);
    const solidColliders: AABB2[] = [];
    for (const f of CHINESE_GALLERY_LAYOUT.features ?? []) {
      if (f.solid === true) {
        solidColliders.push({ minX: f.minX, maxX: f.maxX, minZ: f.minZ, maxZ: f.maxZ });
      }
    }
    this.controller.setColliders(solidColliders);

    try {
      hilog.info(DOMAIN, 'ChineseGalleryScene', 'start loading Chinese gallery');
      const scene: Scene = await Scene.load(
        $rawfile('gltf/chinese_gallery/scene.gltf')
      );
      hilog.info(DOMAIN, 'ChineseGalleryScene', 'scene loaded OK');

      const factory: SceneResourceFactory = scene.getResourceFactory();

      const camParams: SceneNodeParameters = { name: 'chineseCam' };
      const cam: Camera = await factory.createCamera(camParams);
      cam.enabled = true;
      cam.fov = 70 * Math.PI / 180;
      cam.nearPlane = 0.1;
      cam.farPlane = 80.0;
      // 暖纸色 clearColor，中式美学
      cam.clearColor = { r: 0.76, g: 0.74, b: 0.69, a: 1.0 };
      this.controller.attach(cam);

      const warmAmber: RGBA = { r: 0.98, g: 0.92, b: 0.80, a: 1.0 };
      const softCream: RGBA = { r: 0.96, g: 0.93, b: 0.88, a: 1.0 };
      const pureWhite: RGBA = { r: 0.96, g: 0.97, b: 0.98, a: 1.0 };

      // 主光：顶部暖色下照，负责屋面与木构塑形
      const lightKeyParams: SceneNodeParameters = { name: 'chineseKey' };
      const lightKey: Light = await factory.createLight(lightKeyParams, LightType.DIRECTIONAL);
      lightKey.enabled = true;
      lightKey.color = warmAmber;
      lightKey.intensity = 10.5;
      lightKey.rotation = { x: -0.6088, y: 0, z: 0, w: 0.7934 };

      // 冷色填光，模拟花窗透入的天光
      const lightFillParams: SceneNodeParameters = { name: 'chineseFill' };
      const lightFill: Light = await factory.createLight(lightFillParams, LightType.DIRECTIONAL);
      lightFill.enabled = true;
      lightFill.color = { r: 0.76, g: 0.80, b: 0.86, a: 1.0 };
      lightFill.intensity = 3.2;
      lightFill.rotation = { x: 0, y: 1, z: 0, w: 0 };

      // 侧面暖色补光，抬出柱梁轮廓
      const lightSideParams: SceneNodeParameters = { name: 'chineseSide' };
      const lightSide: Light = await factory.createLight(lightSideParams, LightType.DIRECTIONAL);
      lightSide.enabled = true;
      lightSide.color = softCream;
      lightSide.intensity = 2.6;
      lightSide.rotation = { x: -0.166, y: 0.487, z: 0.094, w: 0.853 };

      // 顶部柔和环境补光，只消除死黑
      const lightTopParams: SceneNodeParameters = { name: 'chineseTop' };
      const lightTop: Light = await factory.createLight(lightTopParams, LightType.DIRECTIONAL);
      lightTop.enabled = true;
      lightTop.color = pureWhite;
      lightTop.intensity = 3.8;
      lightTop.rotation = { x: -0.7071, y: 0, z: 0, w: 0.7071 };

      this.sceneInstance = scene;
      this.sceneReady = true;
      this.speech.init();
      this.bgm.init(getContext(this));

      animateTo({ duration: 500, curve: Curve.EaseInOut }, () => {
        this.sceneOpacity = 1;
      });
      setTimeout(() => {
        animateTo({ duration: 500, curve: Curve.EaseInOut }, () => {
          this.loadingOpacity = 0;
        });
      }, 120);
      this.stopDotsAnimation();
      setTimeout(() => {
        this.playIntro();
      }, 900);
    } catch (e) {
      const err = e as BusinessError;
      this.errorMsg = err.message ?? JSON.stringify(e);
      hilog.error(DOMAIN, 'ChineseGalleryScene', 'init failed: %{public}s', JSON.stringify(e));
      this.stopDotsAnimation();
    }
  }

  aboutToDisappear(): void {
    this.controller.detach();
    this.stopDotsAnimation();
    this.speech.stop();
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

  // —— 兰亭序之谜 · 开场 & 观察 ——

  private playIntro(): void {
    if (this.introShown) return;
    this.introShown = true;
    this.introVisible = true;
    animateTo({ duration: 900, curve: Curve.EaseIn }, () => {
      this.introOpacity = 1;
    });
    this.speech.speak(
      '东晋永和九年，王羲之挥毫写下《兰亭序》。传说真迹随唐太宗葬入昭陵，永绝于世。' +
      '但近年有学者考证，太宗可能以摹本代葬，真迹被秘密藏入某幅名画的夹层之中。' +
      '六声墨语藏在六幅画中。聆听它们，找到兰亭序真正的居所。'
    );
    setTimeout(() => {
      animateTo({ duration: 900, curve: Curve.EaseOut }, () => {
        this.introOpacity = 0;
      });
      setTimeout(() => {
        this.introVisible = false;
      }, 900);
    }, 4800);
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
    const c: Clue | undefined = clueForExhibit(this.modalExhibitId);
    if (c !== undefined) {
      this.speech.speakNow(c.whisper);
    }
    setTimeout(() => {
      if (this.modalVisible && this.modalExhibitId === this.currentExhibitId) {
        this.modalVisible = false;
      }
    }, 1500);
  }

  private closeObservation(): void {
    this.modalVisible = false;
  }

  private openNotebook(): void {
    this.modalVisible = false;
    this.notebookVisible = true;
  }

  private closeNotebook(): void {
    this.notebookVisible = false;
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#0a0a0f')

      if (this.sceneReady && this.sceneInstance !== undefined) {
        Component3D({ scene: this.sceneInstance })
          .width('100%')
          .height('100%')
          .backgroundColor('#0a0a0f')
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
          .backgroundColor('#1a1a1a88')
          .fontColor('#ffffff')
          .onClick(() => {
            router.back();
          })

        Text('中国馆  |  拖动转视角 · 点小地图或下方按钮切换')
          .fontSize(14)
          .fontColor('#d4b678')
          .margin({ left: 12 })
      }
      .position({ x: 20, y: 20 })

      // 右上角小地图
      Minimap({
        waypoints: CHINESE_GALLERY_WAYPOINTS,
        layout: CHINESE_GALLERY_LAYOUT,
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

      // 顶部居中展品介绍卡
      ExhibitCard({
        exhibitId: this.currentExhibitId,
        clueState: this.getClueState(this.currentExhibitId),
        exhibit: findChineseExhibit(this.currentExhibitId),
        onObserve: () => {
          this.openObservation();
        }
      })
        .position({ x: '50%', y: 70 })
        .markAnchor({ x: 260, y: 0 })

      // 右侧线索计数器
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
      .backgroundColor('#E61a1a2e')
      .borderColor('#88d4b678')
      .borderWidth(1)
      .borderRadius(18)
      .position({ x: '100%', y: 188 })
      .markAnchor({ x: 82, y: 0 })
      .onClick(() => {
        this.openNotebook();
      })

      // 设置按钮
      Row() {
        Image($r('app.media.icon_gear'))
          .width(18)
          .height(18)
          .fillColor('#8a8a9a')
      }
      .width(36)
      .height(36)
      .backgroundColor('#E61a1a2e')
      .borderColor('#338a8a9a')
      .borderWidth(1)
      .borderRadius(18)
      .justifyContent(FlexAlign.Center)
      .position({ x: '100%', y: 230 })
      .markAnchor({ x: 42, y: 0 })
      .onClick(() => {
        this.settingsVisible = true;
      })

      // 观察模态（线索发现）
      if (this.modalVisible) {
        ObservationModal({
          exhibitId: this.modalExhibitId,
          clue: clueForExhibit(this.modalExhibitId),
          alreadyCollected: this.modalAlreadyCollected,
          onCollect: (clueId: string) => {
            this.collectClue(clueId);
          },
          onClose: () => {
            this.closeObservation();
          }
        })
      }

      // 笔记本模态
      if (this.notebookVisible) {
        NotebookModal({
          discoveredClueIds: this.discoveredClueIds,
          onClose: () => {
            this.closeNotebook();
          }
        })
      }

      // 设置模态
      if (this.settingsVisible) {
        SettingsModal({
          visible: this.settingsVisible,
          voiceOn: this.voiceOn,
          musicOn: this.musicOn,
          onClose: (): void => { this.settingsVisible = false; },
          onVoiceToggle: (): void => {
            this.voiceOn = !this.voiceOn;
            this.speech.toggleMute();
          },
          onMusicToggle: (): void => {
            this.musicOn = !this.musicOn;
            if (this.musicOn) {
              this.bgm.play();
            } else {
              this.bgm.pause();
            }
          }
        })
      }

      // 加载覆盖层
      if (this.loadingOpacity > 0) {
        Column({ space: 12 }) {
          Text('中国馆' + this.loadingDots)
            .fontSize(22)
            .fontColor('#d4b678')
            .fontWeight(FontWeight.Medium)
            .letterSpacing(6)
          Text('兰亭序之谜 · 12 幅传世名画')
            .fontSize(12)
            .fontColor('#6a7a6a')
            .letterSpacing(2)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#0a0a0f')
        .justifyContent(FlexAlign.Center)
        .opacity(this.loadingOpacity)
      }

      // 开场独白覆盖层
      if (this.introVisible) {
        Column() {
          Text('兰亭序之谜')
            .fontSize(28)
            .fontColor('#d4b678')
            .fontWeight(FontWeight.Bold)
            .letterSpacing(8)
            .margin({ bottom: 24 })
          Text('六声墨语 · 藏于画中')
            .fontSize(14)
            .fontColor('#8a9a8a')
            .letterSpacing(4)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#0a0a0f')
        .justifyContent(FlexAlign.Center)
        .opacity(this.introOpacity)
      }
    }
  }
}
