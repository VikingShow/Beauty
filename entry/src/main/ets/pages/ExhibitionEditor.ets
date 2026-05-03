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
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { OrbitCameraController } from '../controllers/OrbitCameraController';
import { FirstPersonCameraController } from '../controllers/FirstPersonCameraController';
import { ParsedSlot, Placement, ArtworkEntry, PRESET_ARTWORKS, PRESET_SCENES, SceneEntry, getPresetSlots, getPaintingSlots, getSculptureSlots, getSpawnSlot } from '../scenes/SlotParser';
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
  @State private showScenePicker: boolean = false;
  @State private loadingOpacity: number = 1;
  @State private sceneOpacity: number = 0;
  @State private userArtworks: ArtworkEntry[] = [];
  @State private uploadError: string = '';
  @State private fineTuneSlotId: string = '';
  @State private currentSceneId: string = 'white_cube';

  private sceneInstance: Scene | undefined = undefined;
  private mainCamera: Camera | undefined = undefined;
  private allSlots: ParsedSlot[] = [];
  private orbitController: OrbitCameraController = new OrbitCameraController(12, 0.008, 3, 25);
  private fpsController: FirstPersonCameraController = new FirstPersonCameraController(DEFAULT_SPAWN);

  async aboutToAppear(): Promise<void> {
    await this.loadCurrentScene();
  }

  private getSceneResource(): Resource {
    if (this.currentSceneId === 'salon_carre') {
      return $rawfile('gltf/salon_carre/scene.gltf');
    }
    return $rawfile('gltf/white_cube/scene.gltf');
  }

  private async loadCurrentScene(): Promise<void> {
    this.sceneReady = false;
    this.sceneOpacity = 0;
    this.loadingOpacity = 1;
    this.allSlots = getPresetSlots(this.currentSceneId);
    this.placements = [];

    // Detach old controller
    this.orbitController.detach();
    this.fpsController.detach();

    try {
      hilog.info(DOMAIN, 'Editor', 'loading scene: %{public}s', this.currentSceneId);
      const scene: Scene = await Scene.load(this.getSceneResource());
      hilog.info(DOMAIN, 'Editor', 'scene loaded');

      const factory: SceneResourceFactory = scene.getResourceFactory();

      const camParams: SceneNodeParameters = { name: 'editorCamera' };
      const cam: Camera = await factory.createCamera(camParams);
      cam.enabled = true;
      cam.fov = 65 * Math.PI / 180;
      cam.nearPlane = 0.1;
      cam.farPlane = 80.0;
      cam.clearColor = { r: 0.15, g: 0.12, b: 0.12, a: 1.0 };
      this.mainCamera = cam;

      this.orbitController = new OrbitCameraController(
        this.currentSceneId === 'salon_carre' ? 18 : 12, 0.008, 3, 35
      );
      this.orbitController.attach(cam);

      // 灯光 —— Salon Carré 用暖暗光
      const white: RGBA = { r: 1.0, g: 1.0, b: 1.0, a: 1.0 };
      const warm: RGBA = { r: 1.0, g: 0.95, b: 0.85, a: 1.0 };
      const fillColor: RGBA = { r: 0.8, g: 0.82, b: 0.9, a: 1.0 };

      const topLightParams: SceneNodeParameters = { name: 'topLight' };
      const lightTop: Light = await factory.createLight(topLightParams, LightType.DIRECTIONAL);
      lightTop.enabled = true;
      lightTop.color = white;
      lightTop.intensity = this.currentSceneId === 'salon_carre' ? 6.0 : 10.0;
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
      this.editMode = true;
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

  private switchScene(sceneId: string): void {
    if (sceneId === this.currentSceneId) {
      this.showScenePicker = false;
      return;
    }
    this.currentSceneId = sceneId;
    this.showScenePicker = false;
    this.loadCurrentScene();
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
    const artwork = this.getAllArtworks().find(a => a.id === this.selectedArtworkId);
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

  private adjustPlacement(slotId: string, dX: number, dY: number): void {
    const updated: Placement[] = [];
    for (const p of this.placements) {
      if (p.slotId === slotId) {
        const adjusted: Placement = {
          slotId: p.slotId,
          artworkId: p.artworkId,
          artworkTitle: p.artworkTitle,
          scale: p.scale,
          offsetX: p.offsetX + dX,
          offsetY: p.offsetY + dY
        };
        updated.push(adjusted);
      } else {
        updated.push(p);
      }
    }
    this.placements = updated;
  }

  private getFineTunePlacement(): Placement | undefined {
    if (this.fineTuneSlotId === '') return undefined;
    return this.getPlacementForSlot(this.fineTuneSlotId);
  }

  private fineTuneOffset(dX: number, dY: number): void {
    this.adjustPlacement(this.fineTuneSlotId, dX, dY);
  }

  private fineTuneScale(delta: number): void {
    const p = this.getFineTunePlacement();
    if (p === undefined) return;
    const updated: Placement[] = [];
    for (const pl of this.placements) {
      if (pl.slotId === this.fineTuneSlotId) {
        const newScale: number = Math.max(0.3, Math.min(2.0, pl.scale + delta));
        const scaled: Placement = {
          slotId: pl.slotId,
          artworkId: pl.artworkId,
          artworkTitle: pl.artworkTitle,
          scale: newScale,
          offsetX: pl.offsetX,
          offsetY: pl.offsetY
        };
        updated.push(scaled);
      } else {
        updated.push(pl);
      }
    }
    this.placements = updated;
  }

  private filledCount(): number {
    return this.placements.length;
  }

  private totalSlots(): number {
    return getPaintingSlots(this.allSlots).length + getSculptureSlots(this.allSlots).length;
  }

  private getSceneName(): string {
    const s = PRESET_SCENES.find(sc => sc.id === this.currentSceneId);
    return s !== undefined ? s.name : '选择场景';
  }

  private getSelectedTitle(): string {
    const a = this.getAllArtworks().find(art => art.id === this.selectedArtworkId);
    return a !== undefined ? a.titleZh + ' - ' + a.artist : '';
  }

  private getAllArtworks(): ArtworkEntry[] {
    return PRESET_ARTWORKS.concat(this.userArtworks);
  }

  private async pickAndAddArtwork(): Promise<void> {
    try {
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await photoPicker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });
      const uris: string[] = result.photoUris;
      if (uris.length === 0) return;
      const uri: string = uris[0];

      // Generate unique ID and create artwork entry
      const timestamp: number = Date.now();
      const newId: string = 'user_' + timestamp.toString();
      const newArtwork: ArtworkEntry = {
        id: newId,
        titleZh: '我的作品 ' + (this.userArtworks.length + 1).toString(),
        titleEn: 'My Artwork ' + (this.userArtworks.length + 1).toString(),
        artist: '未知',
        imageUri: uri,
        type: 'painting'
      };
      this.userArtworks = this.userArtworks.concat([newArtwork]);
      this.selectedArtworkId = newId;
      hilog.info(DOMAIN, 'Editor', 'uploaded artwork: %{public}s', uri);
    } catch (e) {
      const err = e as BusinessError;
      this.uploadError = err.message ?? '上传失败';
      hilog.error(DOMAIN, 'Editor', 'upload failed: %{public}s', JSON.stringify(e));
    }
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

        Button(this.getSceneName())
          .fontSize(14)
          .height(36)
          .backgroundColor('#2a2a2e88')
          .fontColor('#d4b678')
          .borderColor('#d4b67844')
          .borderWidth(1)
          .onClick(() => { this.showScenePicker = !this.showScenePicker; })

        Blank()

        Text(`已放置 ${this.filledCount()} / ${this.totalSlots()}`)
          .fontSize(13)
          .fontColor('#b9a57a')

        Button('导出')
          .fontSize(12)
          .height(36)
          .backgroundColor('#2a2a3a')
          .fontColor('#b9a57a')
          .onClick(() => { this.exportPlacements(); })

        Button('导入')
          .fontSize(12)
          .height(36)
          .backgroundColor('#2a2a3a')
          .fontColor('#b9a57a')
          .onClick(() => { this.importPlacements(); })

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
        // 场景选择覆盖层
        if (this.showScenePicker) {
          Column() {
            Column({ space: 8 }) {
              Text('选择场景')
                .fontSize(16)
                .fontColor('#f5e6c8')
                .fontWeight(FontWeight.Medium)

              ForEach(PRESET_SCENES, (scene: SceneEntry) => {
                Row({ space: 10 }) {
                  Text(scene.name)
                    .fontSize(14)
                    .fontColor(this.currentSceneId === scene.id ? '#d4b678' : '#8a8a9a')
                    .fontWeight(this.currentSceneId === scene.id ? FontWeight.Bold : FontWeight.Normal)
                  Text(scene.description)
                    .fontSize(11)
                    .fontColor('#6a6a7a')
                }
                .width('100%')
                .padding(10)
                .backgroundColor(this.currentSceneId === scene.id ? '#2a2a3a' : '#1a1a2e')
                .borderRadius(8)
                .onClick(() => { this.switchScene(scene.id); })
              }, (scene: SceneEntry) => scene.id)

              Button('关闭')
                .fontSize(12).height(32)
                .backgroundColor('#3a3a3a').fontColor('#aaaaaa')
                .onClick(() => { this.showScenePicker = false; })
            }
            .width(300)
            .padding(16)
            .backgroundColor('#1a1a2eF0')
            .borderColor('#d4b67844')
            .borderWidth(1)
            .borderRadius(12)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('#00000044')
          .position({ x: 0, y: 0 })
          .onClick(() => { this.showScenePicker = false; })
        }

        // 微调面板（居中覆盖层）
        if (this.fineTuneSlotId !== '') {
          Column() {
            this.buildFineTunePanel()
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('#00000044')
          .position({ x: 0, y: 0 })
        }

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
          // 上传按钮
          Column({ space: 4 }) {
            Row() {
              Text('+')
                .fontSize(22)
                .fontColor('#d4b678')
            }
            .width(72)
            .height(54)
            .backgroundColor('#2a2a38')
            .borderColor('#d4b678')
            .borderWidth(1)
            .borderRadius(6)
            .borderStyle(BorderStyle.Dashed)
            .justifyContent(FlexAlign.Center)

            Text('上传图片')
              .fontSize(10)
              .fontColor('#d4b678')
          }
          .onClick(() => { this.pickAndAddArtwork(); })

          // 预置艺术品 + 用户上传
          ForEach(this.getAllArtworks(), (artwork: ArtworkEntry) => {
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
  buildFineTunePanel() {
    Column({ space: 14 }) {
      Text('微调 · ' + this.fineTuneSlotId)
        .fontSize(16)
        .fontColor('#f5e6c8')
        .fontWeight(FontWeight.Medium)

      Row({ space: 10 }) {
        Text('水平位移')
          .fontSize(12).fontColor('#8a8a9a').width(70)
        Button('-1 cm')
          .fontSize(12).height(32).backgroundColor('#3a3a3a').fontColor('#d4b678')
          .onClick(() => { this.fineTuneOffset(-0.01, 0); })
        Text(this.fineTuneOffsetXStr())
          .fontSize(12).fontColor('#d4b678').width(60).textAlign(TextAlign.Center)
        Button('+1 cm')
          .fontSize(12).height(32).backgroundColor('#3a3a3a').fontColor('#d4b678')
          .onClick(() => { this.fineTuneOffset(0.01, 0); })
      }

      Row({ space: 10 }) {
        Text('垂直位移')
          .fontSize(12).fontColor('#8a8a9a').width(70)
        Button('-1 cm')
          .fontSize(12).height(32).backgroundColor('#3a3a3a').fontColor('#d4b678')
          .onClick(() => { this.fineTuneOffset(0, -0.01); })
        Text(this.fineTuneOffsetYStr())
          .fontSize(12).fontColor('#d4b678').width(60).textAlign(TextAlign.Center)
        Button('+1 cm')
          .fontSize(12).height(32).backgroundColor('#3a3a3a').fontColor('#d4b678')
          .onClick(() => { this.fineTuneOffset(0, 0.01); })
      }

      Row({ space: 10 }) {
        Text('缩放')
          .fontSize(12).fontColor('#8a8a9a').width(70)
        Button('-10%')
          .fontSize(12).height(32).backgroundColor('#3a3a3a').fontColor('#d4b678')
          .onClick(() => { this.fineTuneScale(-0.1); })
        Text(this.fineTuneScaleStr())
          .fontSize(12).fontColor('#d4b678').width(50).textAlign(TextAlign.Center)
        Button('+10%')
          .fontSize(12).height(32).backgroundColor('#3a3a3a').fontColor('#d4b678')
          .onClick(() => { this.fineTuneScale(0.1); })
      }

      Row({ space: 16 }) {
        Button('移除作品')
          .fontSize(12).height(36).backgroundColor('#3a2020').fontColor('#ff6b6b')
          .onClick(() => {
            this.removePlacement(this.fineTuneSlotId);
            this.fineTuneSlotId = '';
          })
        Button('完成')
          .fontSize(12).height(36).backgroundColor('#d4b678').fontColor('#1a1a1a')
          .onClick(() => { this.fineTuneSlotId = ''; })
      }
    }
    .width(320)
    .padding(20)
    .backgroundColor('#1a1a2eF0')
    .borderColor('#d4b678')
    .borderWidth(1)
    .borderRadius(12)
  }

  private fineTuneOffsetXStr(): string {
    const p = this.getFineTunePlacement();
    if (p === undefined) return '0.000';
    return (p.offsetX * 100).toFixed(1).toString() + 'cm';
  }
  private fineTuneOffsetYStr(): string {
    const p = this.getFineTunePlacement();
    if (p === undefined) return '0.000';
    return (p.offsetY * 100).toFixed(1).toString() + 'cm';
  }
  private fineTuneScaleStr(): string {
    const p = this.getFineTunePlacement();
    if (p === undefined) return '90%';
    return (p.scale * 100).toFixed(0).toString() + '%';
  }

  private exportPlacements(): void {
    try {
      const data = {
        sceneId: 'white_cube',
        exportedAt: new Date().toISOString(),
        placements: this.placements
      };
      const json: string = JSON.stringify(data);
      const context = getContext(this);
      const dir: string = context.filesDir;
      const path: string = dir + '/exhibition_' + Date.now().toString() + '.json';
      const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, json);
      fileIo.closeSync(file);
      this.uploadError = '';
      hilog.info(DOMAIN, 'Editor', 'exported to: %{public}s', path);
    } catch (e) {
      const err = e as BusinessError;
      this.uploadError = '导出失败: ' + (err.message ?? '');
      hilog.error(DOMAIN, 'Editor', 'export failed: %{public}s', JSON.stringify(e));
    }
  }

  private importPlacements(): void {
    try {
      const context = getContext(this);
      const dir: string = context.filesDir;
      // List JSON files in filesDir
      const files: string[] = fileIo.listFileSync(dir);
      // Find the most recent exhibition JSON
      let latestPath: string = '';
      let latestTime: number = 0;
      for (const f of files) {
        if (f.startsWith('exhibition_') && f.endsWith('.json')) {
          const fullPath: string = dir + '/' + f;
          const stat: fileIo.Stat = fileIo.statSync(fullPath);
          if (stat.mtime > latestTime) {
            latestTime = stat.mtime;
            latestPath = fullPath;
          }
        }
      }
      if (latestPath === '') {
        this.uploadError = '未找到导出的展览文件';
        return;
      }
      const content: string = fileIo.readTextSync(latestPath);
      const data = JSON.parse(content) as Record<string, Object>;
      const imported: Object[] = data['placements'] as Object[];
      if (imported === undefined || imported.length === 0) {
        this.uploadError = '文件中无放置数据';
        return;
      }
      const newPlacements: Placement[] = [];
      for (const obj of imported) {
        const record = obj as Record<string, Object>;
        const p: Placement = {
          slotId: (record['slotId'] as string) ?? '',
          artworkId: (record['artworkId'] as string) ?? '',
          artworkTitle: (record['artworkTitle'] as string) ?? '',
          scale: (record['scale'] as number) ?? 0.9,
          offsetX: (record['offsetX'] as number) ?? 0,
          offsetY: (record['offsetY'] as number) ?? 0
        };
        newPlacements.push(p);
      }
      this.placements = newPlacements;
      this.uploadError = '';
      hilog.info(DOMAIN, 'Editor', 'imported %{public}d placements', newPlacements.length);
    } catch (e) {
      const err = e as BusinessError;
      this.uploadError = '导入失败: ' + (err.message ?? '');
      hilog.error(DOMAIN, 'Editor', 'import failed: %{public}s', JSON.stringify(e));
    }
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
            .onClick(() => {
              if (this.getPlacementForSlot(slot.slotId) !== undefined) {
                this.fineTuneSlotId = slot.slotId;
              } else {
                this.placeInSlot(slot);
              }
            })
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
            .onClick(() => {
              if (this.getPlacementForSlot(slot.slotId) !== undefined) {
                this.fineTuneSlotId = slot.slotId;
              } else {
                this.placeInSlot(slot);
              }
            })
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
