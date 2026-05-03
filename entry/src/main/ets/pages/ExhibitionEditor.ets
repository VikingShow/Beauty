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
import { OrbitCameraController } from '../controllers/OrbitCameraController';
import { FirstPersonCameraController } from '../controllers/FirstPersonCameraController';
import { ParsedSlot, Placement, ArtworkEntry, PRESET_ARTWORKS, getPresetSlots, getPaintingSlots, getSculptureSlots, getSpawnSlot } from '../scenes/SlotParser';
import { Waypoint, Vec2 } from '../scenes/Waypoint';
import { AABB2 } from '../controllers/FirstPersonCameraController';
import { Joystick } from '../components/Joystick';

const DOMAIN = 0x0103;

interface RGBA {
  r: number;
  g: number;
  b: number;
  a: number;
}

const DEFAULT_SPAWN: Waypoint = {
  id: 'spawn', name: '入口',
  position: { x: 0, y: 1.65, z: 3.5 },
  yaw: 0, pitch: 0
};
const EMPTY_COLLIDERS: AABB2[] = [];

/**
 * 布展模拟器 · 主编辑页
 *
 * 编辑模式：轨道相机 + 槽位选择 + 艺术品放置
 * 预览模式：第一人称漫游
 */
@Entry
@Component
struct ExhibitionEditor {
  @State private sceneReady: boolean = false;
  @State private errorMsg: string = '';
  @State private editMode: boolean = true;
  @State private selectedArtworkId: string = '';
  @State private placements: Placement[] = [];
  @State private showArtworkPicker: boolean = false;
  @State private showSlotPanel: boolean = false;
  @State private loadingOpacity: number = 1;
  @State private sceneOpacity: number = 0;

  private sceneInstance: Scene | undefined = undefined;
  private mainCamera: Camera | undefined = undefined;
  private allSlots: ParsedSlot[] = [];
  private orbitController: OrbitCameraController = new OrbitCameraController(12, 0.008, 3, 25);
  private fpsController: FirstPersonCameraController = new FirstPersonCameraController(DEFAULT_SPAWN);

  async aboutToAppear(): Promise<void> {
    this.allSlots = getPresetSlots('white_cube');

    try {
      hilog.info(DOMAIN, 'Editor', 'loading White Cube scene');
      const scene: Scene = await Scene.load($rawfile('gltf/white_cube/scene.gltf'));
      hilog.info(DOMAIN, 'Editor', 'scene loaded');

      const factory: SceneResourceFactory = scene.getResourceFactory();

      const camParams: SceneNodeParameters = { name: 'editorCamera' };
      const cam: Camera = await factory.createCamera(camParams);
      cam.enabled = true;
      cam.fov = 65 * Math.PI / 180;
      cam.nearPlane = 0.1;
      cam.farPlane = 60.0;
      cam.clearColor = { r: 0.88, g: 0.90, b: 0.92, a: 1.0 };
      this.mainCamera = cam;

      this.orbitController.attach(cam);

      // 灯光
      const white: RGBA = { r: 1.0, g: 1.0, b: 1.0, a: 1.0 };
      const warm: RGBA = { r: 1.0, g: 0.98, b: 0.93, a: 1.0 };
      const fillColor: RGBA = { r: 0.85, g: 0.88, b: 0.95, a: 1.0 };

      const topLightParams: SceneNodeParameters = { name: 'topLight' };
      const lightTop: Light = await factory.createLight(topLightParams, LightType.DIRECTIONAL);
      lightTop.enabled = true;
      lightTop.color = white;
      lightTop.intensity = 10.0;
      lightTop.rotation = { x: -0.7071, y: 0, z: 0, w: 0.7071 };

      const sideLightParams: SceneNodeParameters = { name: 'sideLight' };
      const lightSide: Light = await factory.createLight(sideLightParams, LightType.DIRECTIONAL);
      lightSide.enabled = true;
      lightSide.color = warm;
      lightSide.intensity = 4.0;
      lightSide.rotation = { x: -0.25, y: 0.45, z: 0.12, w: 0.85 };

      const fillLightParams: SceneNodeParameters = { name: 'fillLight' };
      const lightFill: Light = await factory.createLight(fillLightParams, LightType.DIRECTIONAL);
      lightFill.enabled = true;
      lightFill.color = fillColor;
      lightFill.intensity = 3.0;
      lightFill.rotation = { x: 0.1, y: -0.7, z: 0.05, w: 0.7 };

      this.sceneInstance = scene;
      this.sceneReady = true;
      animateTo({ duration: 400, curve: Curve.EaseInOut }, () => {
        this.sceneOpacity = 1;
      });
      setTimeout(() => {
        animateTo({ duration: 400, curve: Curve.EaseInOut }, () => {
          this.loadingOpacity = 0;
        });
      }, 100);
    } catch (e) {
      const err = e as BusinessError;
      this.errorMsg = err.message ?? JSON.stringify(e);
      hilog.error(DOMAIN, 'Editor', 'load failed: %{public}s', JSON.stringify(e));
    }
  }

  aboutToDisappear(): void {
    this.orbitController.detach();
    this.fpsController.detach();
  }

  private switchToEditMode(): void {
    if (this.editMode) return;
    this.fpsController.detach();
    if (this.mainCamera !== undefined) {
      this.orbitController.attach(this.mainCamera);
    }
    this.editMode = true;
  }

  private switchToPreviewMode(): void {
    if (!this.editMode) return;
    const savedYaw = this.orbitController.getYaw();
    const savedPitch = this.orbitController.getPitch();
    const savedDist = this.orbitController.getDistance();

    this.orbitController.detach();

    const spawn: ParsedSlot | undefined = getSpawnSlot(this.allSlots);
    let spawnX: number = 0;
    let spawnZ: number = 3.5;
    if (spawn !== undefined) {
      spawnX = spawn.positionX;
      spawnZ = spawn.positionZ;
    }
    const spawnPos: Vec2 = { x: spawnX, z: spawnZ };
    const startPos: Waypoint = {
      id: 'spawn', name: '入口',
      position: { x: spawnPos.x, y: 1.65, z: spawnPos.z },
      yaw: 0, pitch: 0
    };
    this.fpsController = new FirstPersonCameraController(startPos);
    const minBound: Vec2 = { x: -7.2, z: -4.7 };
    const maxBound: Vec2 = { x: 7.2, z: 4.7 };
    this.fpsController.setBounds(minBound, maxBound);
    this.fpsController.setColliders(EMPTY_COLLIDERS);

    if (this.mainCamera !== undefined) {
      this.fpsController.attach(this.mainCamera);
    }

    this.orbitController = new OrbitCameraController(savedDist, 0.008, 3, 25);
    this.editMode = false;
  }

  private selectArtwork(artwork: ArtworkEntry): void {
    this.selectedArtworkId = artwork.id;
    this.showArtworkPicker = false;
    this.showSlotPanel = true;
  }

  private placeInSlot(slot: ParsedSlot): void {
    if (this.selectedArtworkId === '') return;
    const artwork = PRESET_ARTWORKS.find(a => a.id === this.selectedArtworkId);
    if (artwork === undefined) return;

    const filtered = this.placements.filter(p => p.slotId !== slot.slotId);
    const newPlacement: Placement = {
      slotId: slot.slotId,
      artworkId: artwork.id,
      artworkTitle: artwork.titleZh,
      scale: 0.9,
      offsetX: 0,
      offsetY: 0
    };
    this.placements = filtered.concat([newPlacement]);
    this.showSlotPanel = false;
  }

  private removePlacement(slotId: string): void {
    this.placements = this.placements.filter(p => p.slotId !== slotId);
  }

  private getPlacementForSlot(slotId: string): Placement | undefined {
    for (const p of this.placements) {
      if (p.slotId === slotId) return p;
    }
    return undefined;
  }

  private filledCount(): number {
    return this.placements.length;
  }

  private totalSlots(): number {
    return getPaintingSlots(this.allSlots).length + getSculptureSlots(this.allSlots).length;
  }

  private getSelectedTitle(): string {
    const a = PRESET_ARTWORKS.find(art => art.id === this.selectedArtworkId);
    return a !== undefined ? a.titleZh + ' - ' + a.artist : '';
  }

  private onOrbitPanStart(): void {
    this.orbitController.onPanStart();
  }
  private onOrbitPanUpdate(e: GestureEvent): void {
    this.orbitController.onPanUpdate(e.offsetX, e.offsetY);
  }
  private onOrbitPanEnd(): void {
    this.orbitController.onPanEnd();
  }
  private onOrbitPinchStart(): void {
    this.orbitController.onPinchStart();
  }
  private onOrbitPinchUpdate(e: GestureEvent): void {
    if (e.scale !== undefined && e.scale > 0) {
      this.orbitController.onPinchUpdate(e.scale);
    }
  }
  private onOrbitPinchEnd(): void {
    this.orbitController.onPinchEnd();
  }

  private onFpsPanStart(): void {
    this.fpsController.onPanStart();
  }
  private onFpsPanUpdate(e: GestureEvent): void {
    this.fpsController.onPanUpdate(e.offsetX, e.offsetY);
  }
  private onFpsPanEnd(): void {
    this.fpsController.onPanEnd();
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#1a1c1e')

      if (this.sceneReady && this.sceneInstance !== undefined) {
        Component3D({ scene: this.sceneInstance })
          .width('100%')
          .height('100%')
          .backgroundColor('#1a1c1e')
          .opacity(this.sceneOpacity)
          .gesture(
            PanGesture({ fingers: 1 })
              .onActionStart(() => {
                if (this.editMode) {
                  this.onOrbitPanStart();
                } else {
                  this.onFpsPanStart();
                }
              })
              .onActionUpdate((e: GestureEvent) => {
                if (this.editMode) {
                  this.onOrbitPanUpdate(e);
                } else {
                  this.onFpsPanUpdate(e);
                }
              })
              .onActionEnd(() => {
                if (this.editMode) {
                  this.onOrbitPanEnd();
                } else {
                  this.onFpsPanEnd();
                }
              })
          )
          .gesture(
            PinchGesture({ fingers: 2 })
              .onActionStart(() => {
                if (this.editMode) {
                  this.onOrbitPinchStart();
                }
              })
              .onActionUpdate((e: GestureEvent) => {
                if (this.editMode) {
                  this.onOrbitPinchUpdate(e);
                }
              })
              .onActionEnd(() => {
                if (this.editMode) {
                  this.onOrbitPinchEnd();
                }
              })
          )
      }

      if (this.errorMsg !== '') {
        Text('加载失败: ' + this.errorMsg)
          .fontColor('#ff6b6b')
          .fontSize(14)
          .position({ x: 20, y: 60 })
      }

      // ——— 顶部栏 ———
      Row({ space: 12 }) {
        Button('← 返回')
          .fontSize(14)
          .height(36)
          .backgroundColor('#2a2a2e88')
          .fontColor('#ffffff')
          .onClick(() => { router.back(); })

        Text('布展模拟器 · MoMA 白立方')
          .fontSize(16)
          .fontColor('#f5e6c8')
          .fontWeight(FontWeight.Medium)

        Blank()

        Text(`已放置 ${this.filledCount()} / ${this.totalSlots()}`)
          .fontSize(13)
          .fontColor('#b9a57a')

        Button(this.editMode ? '预览漫游' : '返回编辑')
          .fontSize(13)
          .height(36)
          .backgroundColor('#d4b678')
          .fontColor('#1a1a1a')
          .onClick(() => {
            if (this.editMode) {
              this.switchToPreviewMode();
            } else {
              this.switchToEditMode();
            }
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 8, bottom: 8 })
      .backgroundColor('#1a1a2eDD')
      .position({ x: 0, y: 0 })

      // ——— 编辑模式 UI ———
      if (this.editMode && this.sceneReady) {
        Column({ space: 8 }) {
          // 默认状态：选择艺术品按钮
          if (!this.showArtworkPicker && !this.showSlotPanel) {
            Row({ space: 12 }) {
              Button('选择艺术品')
                .fontSize(14)
                .height(40)
                .backgroundColor(this.selectedArtworkId !== '' ? '#3a4a3a' : '#d4b678')
                .fontColor(this.selectedArtworkId !== '' ? '#a0c0a0' : '#1a1a1a')
                .onClick(() => { this.showArtworkPicker = true; })

              if (this.selectedArtworkId !== '') {
                Text(this.getSelectedTitle())
                  .fontSize(13)
                  .fontColor('#d4b678')
              }
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ left: 16, right: 16 })
          }

          if (this.showArtworkPicker) {
            this.buildArtworkPicker()
          }

          if (this.showSlotPanel && this.selectedArtworkId !== '') {
            this.buildSlotPanel()
          }
        }
        .width('100%')
        .padding({ top: 8, bottom: 12 })
        .backgroundColor('#1a1a2eEE')
        .position({ x: 0, y: '100%' })
        .markAnchor({ x: 0, y: '100%' })
        .translate({ y: this.showArtworkPicker || this.showSlotPanel ? -210 : -52 })
      }

      // ——— 预览模式 UI ———
      if (!this.editMode && this.sceneReady) {
        Joystick({
          onInput: (x: number, y: number) => {
            this.fpsController.setMoveInput(x, y);
          }
        })
          .position({ x: 32, y: '100%' })
          .markAnchor({ x: 0, y: 192 })

        Text('拖动屏幕转视角 · 左下摇杆移动')
          .fontSize(13)
          .fontColor('#8a8a9a88')
          .position({ x: '50%', y: '94%' })
          .markAnchor({ x: 0, y: 0 })
      }

      // 加载覆盖层
      if (this.loadingOpacity > 0) {
        Column({ space: 16 }) {
          LoadingProgress()
            .width(48)
            .height(48)
            .color('#d4b678')
          Text('加载白立方展厅...')
            .fontSize(15)
            .fontColor('#d4b67899')
            .letterSpacing(2)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#1a1c1e')
        .opacity(this.loadingOpacity)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildArtworkPicker() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('选择艺术品')
          .fontSize(14)
          .fontColor('#f5e6c8')
          .fontWeight(FontWeight.Medium)
        Blank()
        Button('取消')
          .fontSize(12)
          .height(30)
          .backgroundColor('#3a3a3a')
          .fontColor('#aaaaaa')
          .onClick(() => { this.showArtworkPicker = false; })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      Scroll() {
        Row({ space: 12 }) {
          ForEach(PRESET_ARTWORKS, (artwork: ArtworkEntry) => {
            Column({ space: 6 }) {
              Row() {
                Text(artwork.titleZh.substring(0, 2))
                  .fontSize(12)
                  .fontColor('#d4b678')
              }
              .width(72)
              .height(54)
              .backgroundColor(this.selectedArtworkId === artwork.id ? '#3a4a3a' : '#2a2a38')
              .borderColor(this.selectedArtworkId === artwork.id ? '#d4b678' : '#4a4a5a')
              .borderWidth(1)
              .borderRadius(6)
              .justifyContent(FlexAlign.Center)

              Text(artwork.titleZh)
                .fontSize(11)
                .fontColor('#d4b678')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width(72)

              Text(artwork.artist)
                .fontSize(10)
                .fontColor('#8a8a9a')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width(72)
            }
            .onClick(() => { this.selectArtwork(artwork); })
          }, (artwork: ArtworkEntry) => artwork.id)
        }
        .padding({ left: 16, right: 16, top: 4 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .height(120)
    }
    .width('100%')
  }

  @Builder
  buildSlotPanel() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('选择放置位置')
          .fontSize(14)
          .fontColor('#f5e6c8')
          .fontWeight(FontWeight.Medium)
        Blank()
        Button('返回')
          .fontSize(12)
          .height(30)
          .backgroundColor('#3a3a3a')
          .fontColor('#aaaaaa')
          .onClick(() => {
            this.showSlotPanel = false;
            this.showArtworkPicker = true;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      Scroll() {
        Row({ space: 10 }) {
          ForEach(getPaintingSlots(this.allSlots), (slot: ParsedSlot) => {
            Column({ space: 4 }) {
              Row() {
                if (this.getPlacementForSlot(slot.slotId) !== undefined) {
                  Image($r('app.media.icon_check'))
                    .width(16)
                    .height(16)
                    .fillColor('#6a6')
                } else {
                  Image($r('app.media.icon_search'))
                    .width(16)
                    .height(16)
                    .fillColor('#d4b678')
                }
              }
              .width(64)
              .height(44)
              .backgroundColor(
                this.getPlacementForSlot(slot.slotId) !== undefined ? '#2a3a2a' : '#2a2a38'
              )
              .borderColor(
                this.getPlacementForSlot(slot.slotId) !== undefined ? '#5a5' : '#4a4a5a'
              )
              .borderWidth(1)
              .borderRadius(6)
              .justifyContent(FlexAlign.Center)

              Text(slot.label)
                .fontSize(11)
                .fontColor(
                  this.getPlacementForSlot(slot.slotId) !== undefined ? '#8a8' : '#d4b678'
                )
            }
            .onClick(() => { this.placeInSlot(slot); })
          }, (slot: ParsedSlot) => slot.slotId)

          ForEach(getSculptureSlots(this.allSlots), (slot: ParsedSlot) => {
            Column({ space: 4 }) {
              Row() {
                Text('雕塑')
                  .fontSize(10)
                  .fontColor(
                    this.getPlacementForSlot(slot.slotId) !== undefined ? '#6a6' : '#d4b678'
                  )
              }
              .width(64)
              .height(44)
              .backgroundColor(
                this.getPlacementForSlot(slot.slotId) !== undefined ? '#2a3a2a' : '#2a2a38'
              )
              .borderColor(
                this.getPlacementForSlot(slot.slotId) !== undefined ? '#5a5' : '#4a4a5a'
              )
              .borderWidth(1)
              .borderRadius(6)
              .justifyContent(FlexAlign.Center)

              Text(slot.label)
                .fontSize(11)
                .fontColor(
                  this.getPlacementForSlot(slot.slotId) !== undefined ? '#8a8' : '#d4b678'
                )
            }
            .onClick(() => { this.placeInSlot(slot); })
          }, (slot: ParsedSlot) => slot.slotId)
        }
        .padding({ left: 16, right: 16, top: 4 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .height(110)
    }
    .width('100%')
  }
}
