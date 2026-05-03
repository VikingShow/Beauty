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
import { FirstPersonCameraController, AABB2 } from '../controllers/FirstPersonCameraController';
import { ParsedSlot } from '../scenes/WhiteCubeSlots';
import {
  Placement, ArtworkEntry, PRESET_ARTWORKS, PRESET_SCENES, SceneEntry,
  getPresetSlots, getPaintingSlots, getSculptureSlots, getSpawnSlot
} from '../scenes/SlotParser';
import { Vec2, Waypoint } from '../scenes/Waypoint';
import {
  WallPlane, WallHit, PlacedArtwork,
  WHITE_CUBE_WALLS, detectWallHit, getWallsForScene
} from '../scenes/WallDetector';
import { Joystick } from '../components/Joystick';

const DOMAIN = 0x0103;

interface RGBA {
  r: number; g: number; b: number; a: number;
}

interface ExportData {
  sceneId: string;
  exportedAt: string;
  placements: Placement[];
}

const MAX_RAY_RANGE: number = 5.0;
const SPAWN_X: number = 0;
const SPAWN_Y: number = 1.65;
const SPAWN_Z: number = 3.5;

@Entry
@Component
struct ExhibitionEditor {
  // --- 3D scene ---
  @State private sceneReady: boolean = false;
  @State private errorMsg: string = '';
  @State private loadingOpacity: number = 1;
  @State private sceneOpacity: number = 0;

  // --- 放置状态 ---
  @State private selectedArtworkId: string = '';
  @State private placements: Placement[] = [];
  @State private placementMode: boolean = false;
  @State private userArtworks: ArtworkEntry[] = [];
  @State private currentSceneId: string = 'white_cube';

  // --- 墙面检测 ---
  @State private wallHitValid: boolean = false;
  @State private wallHitLabel: string = '';
  @State private wallHitScreenX: number = 0;
  @State private wallHitScreenY: number = 0;

  // --- UI 状态 ---
  @State private showHotbar: boolean = true;
  @State private showScenePicker: boolean = false;
  @State private fineTuneSlotId: string = '';
  @State private uploadError: string = '';
  @State private cameraYaw: number = 0;
  @State private cameraPitch: number = 0;

  // --- 内部 ---
  private sceneInstance: Scene | undefined = undefined;
  private mainCamera: Camera | undefined = undefined;
  private fps: FirstPersonCameraController = new FirstPersonCameraController(
    { id: 'spawn', name: 'spawn', position: { x: SPAWN_X, y: SPAWN_Y, z: SPAWN_Z }, yaw: 0, pitch: 0 }
  );
  private walls: WallPlane[] = WHITE_CUBE_WALLS;
  private lastWallHit: WallHit | undefined = undefined;

  async aboutToAppear(): Promise<void> {
    this.walls = getWallsForScene(this.currentSceneId);
    await this.loadScene();
  }

  // ==================== SCENE LOADING ====================

  private getSceneResource(): Resource {
    if (this.currentSceneId === 'salon_carre') {
      return $rawfile('gltf/salon_carre/scene.gltf');
    }
    return $rawfile('gltf/white_cube/scene.gltf');
  }

  private async loadScene(): Promise<void> {
    this.sceneReady = false;
    this.sceneOpacity = 0;
    this.loadingOpacity = 1;
    this.placements = [];
    this.placementMode = false;
    this.fps.detach();

    try {
      hilog.info(DOMAIN, 'Editor', 'loading: %{public}s', this.currentSceneId);
      const scene: Scene = await Scene.load(this.getSceneResource());
      const factory: SceneResourceFactory = scene.getResourceFactory();

      const camParams: SceneNodeParameters = { name: 'fpsCam' };
      const cam: Camera = await factory.createCamera(camParams);
      cam.enabled = true;
      cam.fov = 65 * Math.PI / 180;
      cam.nearPlane = 0.1;
      cam.farPlane = 80.0;
      cam.clearColor = { r: 0.15, g: 0.12, b: 0.12, a: 1.0 };
      this.mainCamera = cam;

      const spawn: ParsedSlot | undefined = getSpawnSlot(getPresetSlots(this.currentSceneId));
      const sx: number = spawn !== undefined ? spawn.positionX : SPAWN_X;
      const sy: number = spawn !== undefined ? spawn.positionY : SPAWN_Y;
      const sz: number = spawn !== undefined ? spawn.positionZ : SPAWN_Z;
      const spawnWp: Waypoint = { id: 'spawn', name: 'spawn', position: { x: sx, y: sy, z: sz }, yaw: 0, pitch: 0 };
      this.fps = new FirstPersonCameraController(spawnWp);
      const bMin: Vec2 = { x: -7.2, z: -4.7 };
      const bMax: Vec2 = { x: 7.2, z: 4.7 };
      this.fps.setBounds(bMin, bMax);
      const emptyCol: AABB2[] = [];
      this.fps.setColliders(emptyCol);
      this.fps.attach(cam);
      this.fps.setOnUpdate(() => { this.onFrameUpdate(); });

      // lights
      const white: RGBA = { r: 1.0, g: 1.0, b: 1.0, a: 1.0 };
      const warm: RGBA = { r: 1.0, g: 0.95, b: 0.85, a: 1.0 };
      const fillC: RGBA = { r: 0.8, g: 0.82, b: 0.9, a: 1.0 };
      const keyIntensity: number = this.currentSceneId === 'salon_carre' ? 6.0 : 10.0;

      const topLp: SceneNodeParameters = { name: 'topLight' };
      const lightTop: Light = await factory.createLight(topLp, LightType.DIRECTIONAL);
      lightTop.enabled = true; lightTop.color = white; lightTop.intensity = keyIntensity;
      lightTop.rotation = { x: -0.7071, y: 0, z: 0, w: 0.7071 };

      const sideLp: SceneNodeParameters = { name: 'sideLight' };
      const lightSide: Light = await factory.createLight(sideLp, LightType.DIRECTIONAL);
      lightSide.enabled = true; lightSide.color = warm; lightSide.intensity = 4.0;
      lightSide.rotation = { x: -0.25, y: 0.45, z: 0.12, w: 0.85 };

      const fillLp: SceneNodeParameters = { name: 'fillLight' };
      const lightFill: Light = await factory.createLight(fillLp, LightType.DIRECTIONAL);
      lightFill.enabled = true; lightFill.color = fillC; lightFill.intensity = 3.0;
      lightFill.rotation = { x: 0.1, y: -0.7, z: 0.05, w: 0.7 };

      this.sceneInstance = scene;
      this.sceneReady = true;
      animateTo({ duration: 500, curve: Curve.EaseInOut }, () => { this.sceneOpacity = 1; });
      setTimeout(() => {
        animateTo({ duration: 500, curve: Curve.EaseInOut }, () => { this.loadingOpacity = 0; });
      }, 120);
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      this.errorMsg = err.message ?? 'load error';
      hilog.error(DOMAIN, 'Editor', 'load failed: %{public}s', JSON.stringify(e));
    }
  }

  aboutToDisappear(): void {
    this.fps.detach();
  }

  // ==================== FRAME UPDATE ====================

  private onFrameUpdate(): void {
    const yaw: number = this.fps.getYaw();
    const pitch: number = this.fps.getPitch();
    this.cameraYaw = yaw;
    this.cameraPitch = pitch;

    if (!this.placementMode) return;

    const cp: number = Math.cos(pitch);
    const dx: number = Math.sin(yaw) * cp;
    const dy: number = -Math.sin(pitch);
    const dz: number = -Math.cos(yaw) * cp;

    const placedList: PlacedArtwork[] = [];
    for (const p of this.placements) {
      let wx: number = 0; let wy: number = 0; let wz: number = 0;
      if (p.worldX !== undefined) {
        wx = p.worldX; wy = p.worldY ?? 0; wz = p.worldZ ?? 0;
      } else {
        const slot: ParsedSlot | undefined = this.findSlotById(p.slotId);
        wx = slot !== undefined ? slot.positionX : 0;
        wy = slot !== undefined ? slot.positionY : 0;
        wz = slot !== undefined ? slot.positionZ : 0;
      }
      const w: number = 1.2;  // default painting width
      const h: number = 0.9;  // default painting height
      placedList.push({ worldX: wx, worldY: wy, worldZ: wz, width: w, height: h });
    }

    const hit: WallHit | undefined = detectWallHit(
      this.fps.getPositionX(), this.fps.getPositionY(), this.fps.getPositionZ(),
      dx, dy, dz, this.walls, placedList, MAX_RAY_RANGE
    );

    if (hit === undefined) {
      this.wallHitValid = false;
      this.wallHitLabel = '';
      this.lastWallHit = undefined;
      return;
    }

    const screenW: number = 1920;
    const screenH: number = 1080;
    const fov: number = 65 * Math.PI / 180;
    const sp: ScreenPoint = this.project3DTo2D(
      hit.worldX, hit.worldY, hit.worldZ,
      this.fps.getPositionX(), this.fps.getPositionY(), this.fps.getPositionZ(),
      yaw, pitch, screenW, screenH, fov
    );

    this.wallHitValid = hit.valid;
    this.wallHitLabel = hit.wallLabel;
    this.wallHitScreenX = sp.x;
    this.wallHitScreenY = sp.y;
    this.lastWallHit = hit;
  }

  private project3DTo2D(
    wx: number, wy: number, wz: number,
    cx: number, cy: number, cz: number,
    yaw: number, pitch: number,
    sw: number, sh: number, fovY: number
  ): ScreenPoint {
    const dx: number = wx - cx;
    const dy: number = wy - cy;
    const dz: number = wz - cz;
    const cosY: number = Math.cos(-yaw);
    const sinY: number = Math.sin(-yaw);
    const cosP: number = Math.cos(-pitch);
    const sinP: number = Math.sin(-pitch);
    const rx: number = dx * cosY - dz * sinY;
    const rz: number = dx * sinY + dz * cosY;
    const ry: number = dy * cosP - rz * sinP;
    const rz2: number = dy * sinP + rz * cosP;
    if (rz2 <= 0.01) {
      const hidden: ScreenPoint = { x: -100, y: -100, visible: false };
      return hidden;
    }
    const aspect: number = sw / sh;
    const halfH: number = Math.tan(fovY / 2);
    const halfW: number = halfH * aspect;
    const sx: number = (rx / rz2) / halfW;
    const sy: number = -(ry / rz2) / halfH;
    const result: ScreenPoint = {
      x: (sx + 1) / 2 * sw,
      y: (sy + 1) / 2 * sh,
      visible: sx > -1.2 && sx < 1.2 && sy > -1.2 && sy < 1.2
    };
    return result;
  }

  // ==================== PLACEMENT ====================

  private selectArtwork(artwork: ArtworkEntry): void {
    this.selectedArtworkId = artwork.id;
    this.placementMode = true;
  }

  private enterPlacementMode(): void {
    this.placementMode = true;
  }

  private cancelPlacement(): void {
    this.placementMode = false;
    this.selectedArtworkId = '';
    this.wallHitValid = false;
    this.lastWallHit = undefined;
  }

  private placeCurrentArtwork(): void {
    if (!this.placementMode || this.lastWallHit === undefined || !this.lastWallHit.valid) return;
    const artwork: ArtworkEntry | undefined =
      this.getAllArtworks().find(a => a.id === this.selectedArtworkId);
    if (artwork === undefined) return;

    const slotId: string = 'custom_' + Date.now().toString();
    const p: Placement = {
      slotId: slotId,
      artworkId: artwork.id,
      artworkTitle: artwork.titleZh,
      scale: 0.9,
      offsetX: 0,
      offsetY: 0,
      worldX: this.lastWallHit.worldX,
      worldY: this.lastWallHit.worldY,
      worldZ: this.lastWallHit.worldZ
    };
    this.placements = this.placements.concat([p]);
    this.wallHitValid = false;
    this.lastWallHit = undefined;
  }

  private removePlacement(slotId: string): void {
    const filtered: Placement[] = [];
    for (const p of this.placements) {
      if (p.slotId !== slotId) {
        filtered.push(p);
      }
    }
    this.placements = filtered;
  }

  private getAllArtworks(): ArtworkEntry[] {
    return PRESET_ARTWORKS.concat(this.userArtworks);
  }

  private findSlotById(id: string): ParsedSlot | undefined {
    const all: ParsedSlot[] = getPresetSlots(this.currentSceneId);
    for (const s of all) {
      if (s.slotId === id) return s;
    }
    return undefined;
  }

  private getSceneName(): string {
    for (const s of PRESET_SCENES) {
      if (s.id === this.currentSceneId) return s.name;
    }
    return '选择场景';
  }

  // ==================== FINE TUNE ====================

  private fineTuneOffset(dX: number, dY: number): void {
    const updated: Placement[] = [];
    for (const p of this.placements) {
      if (p.slotId === this.fineTuneSlotId) {
        const adj: Placement = {
          slotId: p.slotId, artworkId: p.artworkId, artworkTitle: p.artworkTitle,
          scale: p.scale, offsetX: p.offsetX + dX, offsetY: p.offsetY + dY
        };
        updated.push(adj);
      } else {
        updated.push(p);
      }
    }
    this.placements = updated;
  }

  private fineTuneScale(delta: number): void {
    const updated: Placement[] = [];
    for (const p of this.placements) {
      if (p.slotId === this.fineTuneSlotId) {
        const ns: number = Math.max(0.3, Math.min(2.0, p.scale + delta));
        const adj: Placement = {
          slotId: p.slotId, artworkId: p.artworkId, artworkTitle: p.artworkTitle,
          scale: ns, offsetX: p.offsetX, offsetY: p.offsetY
        };
        updated.push(adj);
      } else {
        updated.push(p);
      }
    }
    this.placements = updated;
  }

  private getPlacementForSlot(slotId: string): Placement | undefined {
    for (const p of this.placements) {
      if (p.slotId === slotId) return p;
    }
    return undefined;
  }

  // ==================== EXPORT/IMPORT ====================

  private exportPlacements(): void {
    try {
      const data: ExportData = {
        sceneId: this.currentSceneId, exportedAt: new Date().toISOString(),
        placements: this.placements
      };
      const context = getContext(this);
      const path: string = context.filesDir + '/exhibition_' + Date.now().toString() + '.json';
      const file: fileIo.File = fileIo.openSync(
        path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC
      );
      fileIo.writeSync(file.fd, JSON.stringify(data));
      fileIo.closeSync(file);
      hilog.info(DOMAIN, 'Editor', 'exported to: %{public}s', path);
    } catch (e) {
      this.uploadError = '导出失败';
    }
  }

  // ==================== BUILD ====================

  build() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor('#0a0a1a')

      // --- 3D Scene ---
      if (this.sceneReady && this.sceneInstance !== undefined) {
        Component3D({ scene: this.sceneInstance })
          .width('100%').height('100%')
          .backgroundColor('#0a0a1a')
          .opacity(this.sceneOpacity)
          .gesture(
            PanGesture({ fingers: 1 })
              .onActionStart(() => { this.fps.onPanStart(); })
              .onActionUpdate((e: GestureEvent) => { this.fps.onPanUpdate(e.offsetX, e.offsetY); })
              .onActionEnd(() => { this.fps.onPanEnd(); })
          )
      }

      if (this.errorMsg !== '') {
        Text('加载失败: ' + this.errorMsg).fontColor('#ff6b6b').fontSize(14).position({ x: 20, y: 60 })
      }

      // --- Top Bar ---
      Row({ space: 10 }) {
        Button('← 返回', { type: ButtonType.Capsule })
          .fontSize(13).height(34)
          .backgroundColor('#1a1a2e88').fontColor('#ffffff')
          .onClick(() => { router.back(); })

        Button(this.getSceneName() + ' ▾', { type: ButtonType.Capsule })
          .fontSize(13).height(34)
          .backgroundColor('#1a1a2e').fontColor('#d4b678')
          .borderColor('#d4b67844').borderWidth(1)
          .onClick(() => { this.showScenePicker = !this.showScenePicker; })

        Blank()

        Text('已放置 ' + this.placements.length.toString())
          .fontSize(13).fontColor('#b9a57a')

        Button('导出', { type: ButtonType.Capsule })
          .fontSize(12).height(32)
          .backgroundColor('#1a1a2e').fontColor('#b9a57a')
          .borderColor('#d4b67844').borderWidth(1)
          .onClick(() => { this.exportPlacements(); })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor('#1a1a2eDD')
      .position({ x: 0, y: 0 })

      // --- Crosshair (placement mode) ---
      if (this.placementMode) {
        Column() {
          Text('＋')
            .fontSize(28).fontColor('#d4b67888')
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent)
        .position({ x: 0, y: 0 })
      }

      // --- Placement Preview Overlay ---
      if (this.placementMode && this.lastWallHit !== undefined) {
        Row()
          .width(40).height(30)
          .backgroundColor(this.wallHitValid ? '#4400ff0044' : '#44ff000044')
          .borderColor(this.wallHitValid ? '#00ff00' : '#ff4444')
          .borderWidth(2)
          .position({ x: this.wallHitScreenX - 20, y: this.wallHitScreenY - 15 })
          .hitTestBehavior(HitTestMode.Transparent)
      }

      // --- Scene Picker overlay ---
      if (this.showScenePicker) {
        Column() {
          Column({ space: 6 }) {
            Text('选择场景').fontSize(15).fontColor('#f5e6c8').fontWeight(FontWeight.Medium)

            ForEach(PRESET_SCENES, (sc: SceneEntry) => {
              Row({ space: 8 }) {
                Text(sc.name)
                  .fontSize(13)
                  .fontColor(this.currentSceneId === sc.id ? '#d4b678' : '#8a8a9a')
                  .fontWeight(this.currentSceneId === sc.id ? FontWeight.Bold : FontWeight.Normal)
                Text(sc.description).fontSize(10).fontColor('#6a6a7a')
              }
              .width('100%').padding(10)
              .backgroundColor(this.currentSceneId === sc.id ? '#2a2a3a' : '#1a1a2e')
              .borderRadius(8)
              .onClick(() => { this.switchScene(sc.id); })
            }, (sc: SceneEntry) => sc.id)

            Button('关闭', { type: ButtonType.Capsule })
              .fontSize(12).height(30)
              .backgroundColor('#1a1a2e').fontColor('#8a8a9a')
              .onClick(() => { this.showScenePicker = false; })
          }
          .width(260).padding(14)
          .backgroundColor('#F01a1a2e').borderColor('#88d4b678').borderWidth(1).borderRadius(12)
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .backgroundColor('#00000088')
        .position({ x: 0, y: 0 })
        .onClick(() => { this.showScenePicker = false; })
      }

      // --- Joystick ---
      Joystick({
        onInput: (x: number, y: number) => { this.fps.setMoveInput(x, y); }
      })
        .position({ x: 32, y: '100%' }).markAnchor({ x: 0, y: 192 })

      // --- Bottom: Hotbar ---
      if (this.showHotbar) {
        this.buildHotbar()
      }

      // --- Bottom: Placement Bar ---
      if (this.placementMode) {
        this.buildPlacementBar()
      }

      // --- Fine-tune panel ---
      if (this.fineTuneSlotId !== '') {
        this.buildFineTuneOverlay()
      }

      // --- Loading overlay ---
      if (this.loadingOpacity > 0) {
        Column({ space: 16 }) {
          LoadingProgress().width(48).height(48).color('#d4b678')
          Text('加载展厅...').fontSize(15).fontColor('#d4b67899').letterSpacing(2)
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .linearGradient({
          angle: 135,
          colors: [['#0a0a1a', 0], ['#1a1a2e', 0.5], ['#0f0f1f', 1]]
        })
        .opacity(this.loadingOpacity)
      }
    }
    .width('100%').height('100%')
  }

  // ==================== BUILDERS ====================

  private switchScene(sceneId: string): void {
    if (sceneId === this.currentSceneId) {
      this.showScenePicker = false;
      return;
    }
    this.currentSceneId = sceneId;
    this.walls = getWallsForScene(sceneId);
    this.showScenePicker = false;
    this.loadScene();
  }

  @Builder
  buildHotbar() {
    Row({ space: 10 }) {
      // Upload button
      Column({ space: 2 }) {
        Row() {
          Text('+').fontSize(20).fontColor('#d4b678')
        }
        .width(52).height(38)
        .backgroundColor('#1a1a2e').borderColor('#d4b67844').borderWidth(1).borderRadius(8)
        .borderStyle(BorderStyle.Dashed)
        .justifyContent(FlexAlign.Center)
        Text('上传').fontSize(9).fontColor('#8a8a9a')
      }
      .onClick(() => { this.pickAndAddArtwork(); })

      if (this.selectedArtworkId === '') {
        // Show artwork list
        ForEach(this.getAllArtworks(), (art: ArtworkEntry) => {
          Column({ space: 2 }) {
            Row() {
              Text(art.titleZh.substring(0, 2))
                .fontSize(13).fontColor('#d4b678')
            }
            .width(52).height(38)
            .backgroundColor('#1a1a2e').borderColor('#4a4a5a').borderWidth(1).borderRadius(8)
            .justifyContent(FlexAlign.Center)
            Text(art.titleZh)
              .fontSize(9).fontColor('#8a8a9a')
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width(52)
          }
          .onClick(() => { this.selectArtwork(art); })
        }, (art: ArtworkEntry) => art.id)
      } else {
        // Show only selected artwork, highlighted
        ForEach(this.getAllArtworks(), (art: ArtworkEntry) => {
          Column({ space: 2 }) {
            Row() {
              Text(art.titleZh.substring(0, 2))
                .fontSize(13)
                .fontColor(this.selectedArtworkId === art.id ? '#0a0a1a' : '#d4b678')
            }
            .width(52).height(38)
            .backgroundColor(
              this.selectedArtworkId === art.id ? '#d4b678' : '#1a1a2e'
            )
            .borderColor(
              this.selectedArtworkId === art.id ? '#d4b678' : '#4a4a5a'
            )
            .borderWidth(1).borderRadius(8)
            .justifyContent(FlexAlign.Center)
            Text(art.titleZh)
              .fontSize(9)
              .fontColor(this.selectedArtworkId === art.id ? '#f5e6c8' : '#8a8a9a')
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width(52)
          }
          .onClick(() => { this.selectArtwork(art); })
        }, (art: ArtworkEntry) => art.id)
      }
    }
    .padding({ left: 14, right: 14, top: 6, bottom: 6 })
    .backgroundColor('#1a1a2eEE')
    .position({ x: 0, y: '100%' }).markAnchor({ x: 0, y: 88 })
  }

  @Builder
  buildPlacementBar() {
    Row({ space: 12 }) {
      Text('选中：' + this.getSelectedArtworkTitle())
        .fontSize(13).fontColor('#f5e6c8')
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width(180)

      if (this.wallHitValid) {
        Text('墙面：' + this.wallHitLabel)
          .fontSize(12).fontColor('#6a6').padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor('#1a3a1a').borderRadius(8)
      } else if (this.lastWallHit !== undefined) {
        Text(this.lastWallHit.reason !== '' ? this.lastWallHit.reason : '不可放置')
          .fontSize(12).fontColor('#ff6b6b')
      } else {
        Text('看向墙面来预览位置')
          .fontSize(12).fontColor('#8a8a9a')
      }

      Blank()

      Button('放置', { type: ButtonType.Capsule })
        .fontSize(13).height(34)
        .backgroundColor(this.wallHitValid ? '#d4b678' : '#2a2a2e')
        .fontColor(this.wallHitValid ? '#0a0a1a' : '#5a5a6a')
        .onClick(() => { this.placeCurrentArtwork(); })

      Button('✕', { type: ButtonType.Capsule })
        .fontSize(13).height(34).width(40)
        .backgroundColor('#1a1a2e').fontColor('#8a8a9a')
        .onClick(() => { this.cancelPlacement(); })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor('#1a1a2eF5')
    .border({ width: { top: 1 }, color: { top: '#d4b67844' } })
    .position({ x: 0, y: '100%' }).markAnchor({ x: 0, y: 140 })
  }

  @Builder
  buildFineTuneOverlay() {
    Column() {
      Column({ space: 6 }) {
        Text('微调').fontSize(14).fontColor('#f5e6c8').fontWeight(FontWeight.Medium)

        Row({ space: 6 }) {
          Text('±1cm').fontSize(11).fontColor('#8a8a9a')
          Button('←', { type: ButtonType.Capsule }).fontSize(11).height(28).width(36)
            .backgroundColor('#1a1a2e').fontColor('#d4b678')
            .onClick(() => { this.fineTuneOffset(-0.01, 0); })
          Button('→', { type: ButtonType.Capsule }).fontSize(11).height(28).width(36)
            .backgroundColor('#1a1a2e').fontColor('#d4b678')
            .onClick(() => { this.fineTuneOffset(0.01, 0); })
          Button('↑', { type: ButtonType.Capsule }).fontSize(11).height(28).width(36)
            .backgroundColor('#1a1a2e').fontColor('#d4b678')
            .onClick(() => { this.fineTuneOffset(0, 0.01); })
          Button('↓', { type: ButtonType.Capsule }).fontSize(11).height(28).width(36)
            .backgroundColor('#1a1a2e').fontColor('#d4b678')
            .onClick(() => { this.fineTuneOffset(0, -0.01); })
        }

        Row({ space: 6 }) {
          Text('缩放').fontSize(11).fontColor('#8a8a9a')
          Button('-10%', { type: ButtonType.Capsule }).fontSize(11).height(28)
            .backgroundColor('#1a1a2e').fontColor('#d4b678')
            .onClick(() => { this.fineTuneScale(-0.1); })
          Button('+10%', { type: ButtonType.Capsule }).fontSize(11).height(28)
            .backgroundColor('#1a1a2e').fontColor('#d4b678')
            .onClick(() => { this.fineTuneScale(0.1); })
        }

        Row({ space: 10 }) {
          Button('移除', { type: ButtonType.Capsule }).fontSize(12).height(30)
            .backgroundColor('#3a2020').fontColor('#ff6b6b')
            .onClick(() => {
              this.removePlacement(this.fineTuneSlotId);
              this.fineTuneSlotId = '';
            })
          Button('完成', { type: ButtonType.Capsule }).fontSize(12).height(30)
            .backgroundColor('#d4b678').fontColor('#0a0a1a')
            .onClick(() => { this.fineTuneSlotId = ''; })
        }
      }
      .width(260).padding(14)
      .backgroundColor('#F01a1a2e').borderColor('#88d4b678').borderWidth(1).borderRadius(12)
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .backgroundColor('#00000044')
    .position({ x: 0, y: 0 })
  }

  // ==================== HELPERS ====================

  private getSelectedArtworkTitle(): string {
    const a: ArtworkEntry | undefined =
      this.getAllArtworks().find(art => art.id === this.selectedArtworkId);
    return a !== undefined ? a.titleZh : '';
  }

  private async pickAndAddArtwork(): Promise<void> {
    try {
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await photoPicker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE, maxSelectNumber: 1
      });
      const uris: string[] = result.photoUris;
      if (uris.length === 0) return;
      const newId: string = 'user_' + Date.now().toString();
      const na: ArtworkEntry = {
        id: newId,
        titleZh: '我的作品 ' + (this.userArtworks.length + 1).toString(),
        titleEn: 'My Artwork', artist: '未知', imageUri: uris[0], type: 'painting'
      };
      this.userArtworks = this.userArtworks.concat([na]);
      this.selectedArtworkId = newId;
      this.placementMode = true;
    } catch (e) {
      this.uploadError = '上传失败';
    }
  }
}

interface ScreenPoint {
  x: number;
  y: number;
  visible: boolean;
}
