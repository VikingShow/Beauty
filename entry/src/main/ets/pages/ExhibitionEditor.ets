import { router } from '@kit.ArkUI';
import { display } from '@ohos.display';
import {
  Scene, SceneResourceFactory, Camera, Light, LightType, SceneNodeParameters
} from '@kit.ArkGraphics3D';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { FirstPersonCameraController, AABB2 } from '../controllers/FirstPersonCameraController';
import { ParsedSlot } from '../scenes/WhiteCubeSlots';
import {
  Placement, ArtworkEntry, PRESET_ARTWORKS, PRESET_SCENES, SceneEntry,
  getPresetSlots, getSpawnSlot
} from '../scenes/SlotParser';
import { Vec2, Waypoint } from '../scenes/Waypoint';
import {
  WallPlane, WallHit, PlacedArtwork,
  WHITE_CUBE_WALLS, detectWallHit, getWallsForScene
} from '../scenes/WallDetector';
import { Joystick } from '../components/Joystick';

const DOMAIN = 0x0103;
const FRAME_MS = 16;
const MAX_RAY_RANGE = 5.0;
const PAINTING_W = 1.2;
const PAINTING_H = 0.9;

interface RGBA { r: number; g: number; b: number; a: number; }
interface ExportData { sceneId: string; exportedAt: string; placements: Placement[]; }
interface ScreenPoint { x: number; y: number; visible: boolean; }
interface GhostRect { x: number; y: number; w: number; h: number; }

@Entry
@Component
struct ExhibitionEditor {
  // -- 3D scene --
  @State private sceneReady: boolean = false;
  @State private errorMsg: string = '';
  @State private loadingOpacity: number = 1;
  @State private sceneOpacity: number = 0;

  // -- placement --
  @State private selectedArtworkId: string = '';
  @State private placements: Placement[] = [];
  @State private placementMode: boolean = false;
  @State private userArtworks: ArtworkEntry[] = [];
  @State private currentSceneId: string = 'white_cube';

  // -- ghost preview --
  @State private ghostValid: boolean = false;
  @State private ghostVisible: boolean = false;
  @State private ghostX: number = 0;
  @State private ghostY: number = 0;
  @State private ghostW: number = 0;
  @State private ghostH: number = 0;

  // -- placed artwork overlays --
  @State private placedRects: string = ''; // JSON array of GhostRect

  // -- UI --
  @State private showScenePicker: boolean = false;
  @State private showFineTune: boolean = false;
  @State private showHotbar: boolean = true;
  @State private cameraYaw: number = 0;
  @State private cameraPitch: number = 0;

  private sceneInstance: Scene | undefined = undefined;
  private mainCamera: Camera | undefined = undefined;
  private fps: FirstPersonCameraController = new FirstPersonCameraController(
    { id: 's', name: 's', position: { x: 0, y: 1.65, z: 3.5 }, yaw: 0, pitch: 0 }
  );
  private walls: WallPlane[] = WHITE_CUBE_WALLS;
  private lastHit: WallHit | undefined = undefined;
  private frameTimer: number | undefined = undefined;
  private screenW: number = 1920;
  private screenH: number = 1080;

  async aboutToAppear(): Promise<void> {
    // Get real screen dimensions
    try {
      const di = display.getDefaultDisplaySync();
      this.screenW = di.width;
      this.screenH = di.height;
    } catch (e) {
      this.screenW = 1920;
      this.screenH = 1080;
    }

    this.walls = getWallsForScene(this.currentSceneId);
    await this.loadScene();
  }

  private getSceneResource(): Resource {
    if (this.currentSceneId === 'salon_carre') return $rawfile('gltf/salon_carre/scene.gltf');
    return $rawfile('gltf/white_cube/scene.gltf');
  }

  private async loadScene(): Promise<void> {
    this.sceneReady = false; this.sceneOpacity = 0; this.loadingOpacity = 1;
    this.placements = []; this.placementMode = false; this.fps.detach();
    this.stopFrameLoop();
    try {
      const scene: Scene = await Scene.load(this.getSceneResource());
      const factory: SceneResourceFactory = scene.getResourceFactory();
      const camParams: SceneNodeParameters = { name: 'fpsCam' };
      const cam: Camera = await factory.createCamera(camParams);
      cam.enabled = true; cam.fov = 65 * Math.PI / 180;
      cam.nearPlane = 0.1; cam.farPlane = 80.0;
      cam.clearColor = { r: 0.15, g: 0.12, b: 0.12, a: 1.0 };
      this.mainCamera = cam;

      const spawn: ParsedSlot | undefined = getSpawnSlot(getPresetSlots(this.currentSceneId));
      const sx: number = spawn !== undefined ? spawn.positionX : 0;
      const sy: number = spawn !== undefined ? spawn.positionY : 1.65;
      const sz: number = spawn !== undefined ? spawn.positionZ : 3.5;
      const wp: Waypoint = { id: 's', name: 's', position: { x: sx, y: sy, z: sz }, yaw: 0, pitch: 0 };
      this.fps = new FirstPersonCameraController(wp);
      const bMin: Vec2 = { x: -7.2, z: -4.7 };
      const bMax: Vec2 = { x: 7.2, z: 4.7 };
      this.fps.setBounds(bMin, bMax);
      const emptyCol: AABB2[] = [];
      this.fps.setColliders(emptyCol);
      this.fps.attach(cam);
      this.fps.setOnUpdate(() => { this.onFrame(); });

      const white: RGBA = { r: 1.0, g: 1.0, b: 1.0, a: 1.0 };
      const warm: RGBA = { r: 1.0, g: 0.95, b: 0.85, a: 1.0 };
      const fillC: RGBA = { r: 0.8, g: 0.82, b: 0.9, a: 1.0 };
      const ki: number = this.currentSceneId === 'salon_carre' ? 6.0 : 10.0;

      const ltp: SceneNodeParameters = { name: 'tL' };
      const lt: Light = await factory.createLight(ltp, LightType.DIRECTIONAL);
      lt.enabled = true; lt.color = white; lt.intensity = ki;
      lt.rotation = { x: -0.7071, y: 0, z: 0, w: 0.7071 };

      const lsp: SceneNodeParameters = { name: 'sL' };
      const ls: Light = await factory.createLight(lsp, LightType.DIRECTIONAL);
      ls.enabled = true; ls.color = warm; ls.intensity = 4.0;
      ls.rotation = { x: -0.25, y: 0.45, z: 0.12, w: 0.85 };

      const lfp: SceneNodeParameters = { name: 'fL' };
      const lf: Light = await factory.createLight(lfp, LightType.DIRECTIONAL);
      lf.enabled = true; lf.color = fillC; lf.intensity = 3.0;
      lf.rotation = { x: 0.1, y: -0.7, z: 0.05, w: 0.7 };

      this.sceneInstance = scene; this.sceneReady = true;
      this.startFrameLoop();
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
    this.stopFrameLoop();
    this.fps.detach();
  }

  // ==================== FRAME LOOP ====================

  private startFrameLoop(): void {
    this.stopFrameLoop();
    const loop = (): void => {
      this.frameTimer = setTimeout(loop, FRAME_MS);
      this.fps.forceApply();
    };
    this.frameTimer = setTimeout(loop, FRAME_MS);
  }

  private stopFrameLoop(): void {
    if (this.frameTimer !== undefined) {
      clearTimeout(this.frameTimer);
      this.frameTimer = undefined;
    }
  }

  // ==================== FRAME UPDATE ====================

  private onFrame(): void {
    const yaw: number = this.fps.getYaw();
    const pitch: number = this.fps.getPitch();
    this.cameraYaw = yaw;
    this.cameraPitch = pitch;

    const cp: number = Math.cos(pitch);
    const dx: number = Math.sin(yaw) * cp;
    const dy: number = -Math.sin(pitch);
    const dz: number = -Math.cos(yaw) * cp;

    // Placed artwork overlap detection
    const placedList: PlacedArtwork[] = [];
    for (const p of this.placements) {
      let wx: number = 0; let wy: number = 0; let wz: number = 0;
      if (p.worldX !== undefined) { wx = p.worldX; wy = p.worldY ?? 0; wz = p.worldZ ?? 0; }
      placedList.push({ worldX: wx, worldY: wy, worldZ: wz, width: PAINTING_W, height: PAINTING_H });
    }

    // Ghost preview (only in placement mode)
    if (this.placementMode) {
      const hit: WallHit | undefined = detectWallHit(
        this.fps.getPositionX(), this.fps.getPositionY(), this.fps.getPositionZ(),
        dx, dy, dz, this.walls, placedList, MAX_RAY_RANGE
      );
      this.lastHit = hit;
      if (hit !== undefined) {
        this.ghostValid = hit.valid;
        const g: GhostRect = this.computeGhostAt(
          hit.worldX, hit.worldY, hit.worldZ
        );
        this.ghostX = g.x; this.ghostY = g.y; this.ghostW = g.w; this.ghostH = g.h;
        this.ghostVisible = true;
      } else {
        this.ghostVisible = false;
      }
    } else {
      this.ghostVisible = false;
    }

    // Update placed artwork overlays
    this.updatePlacedOverlays();
  }

  private updatePlacedOverlays(): void {
    if (this.placements.length === 0) {
      this.placedRects = '[]';
      return;
    }
    const rects: GhostRect[] = [];
    for (const p of this.placements) {
      let wx: number = 0; let wy: number = 0; let wz: number = 0;
      if (p.worldX !== undefined) { wx = p.worldX; wy = p.worldY ?? 0; wz = p.worldZ ?? 0; }
      const g: GhostRect = this.computeGhostAt(wx, wy, wz);
      if (g.w > 0 && g.h > 0) {
        rects.push(g);
      }
    }
    this.placedRects = JSON.stringify(rects);
  }

  // ==================== PROJECTION ====================

  private computeGhostAt(wx: number, wy: number, wz: number): GhostRect {
    const cx: number = this.fps.getPositionX();
    const cy: number = this.fps.getPositionY();
    const cz: number = this.fps.getPositionZ();
    const yaw: number = this.fps.getYaw();
    const pitch: number = this.fps.getPitch();

    // Project center
    const c: ScreenPoint = this.project(wx, wy, wz, cx, cy, cz, yaw, pitch);

    // Project horizontal extent: offset along world XZ perpendicular to camera view
    // Use the camera's right vector for horizontal screen direction
    const rx: number = Math.cos(yaw);  // right direction in XZ plane
    const rz: number = -Math.sin(yaw);

    const rightPt: ScreenPoint = this.project(
      wx + rx * PAINTING_W / 2, wy, wz + rz * PAINTING_W / 2,
      cx, cy, cz, yaw, pitch
    );
    const topPt: ScreenPoint = this.project(
      wx, wy + PAINTING_H / 2, wz,
      cx, cy, cz, yaw, pitch
    );

    const hw: number = Math.abs(rightPt.x - c.x) * 2;
    const hh: number = Math.abs(c.y - topPt.y) * 2;
    const r: GhostRect = {
      x: c.x - hw / 2, y: c.y - hh / 2,
      w: hw > 10 ? hw : 80, h: hh > 10 ? hh : 60
    };
    return r;
  }

  private project(
    wx: number, wy: number, wz: number,
    cx: number, cy: number, cz: number,
    yaw: number, pitch: number
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
      const r: ScreenPoint = { x: -200, y: -200, visible: false };
      return r;
    }
    const fovY: number = 65 * Math.PI / 180;
    const halfH: number = Math.tan(fovY / 2);
    const halfW: number = halfH * (this.screenW / this.screenH);
    const sx: number = (rx / rz2) / halfW;
    const sy: number = -(ry / rz2) / halfH;
    const r: ScreenPoint = {
      x: (sx + 1) / 2 * this.screenW,
      y: (sy + 1) / 2 * this.screenH,
      visible: sx > -1.3 && sx < 1.3 && sy > -1.3 && sy < 1.3
    };
    return r;
  }

  // ==================== ACTIONS ====================

  private selectArtwork(art: ArtworkEntry): void {
    this.selectedArtworkId = art.id;
    this.placementMode = true;
  }

  private cancelPlacement(): void {
    this.placementMode = false;
    this.selectedArtworkId = '';
    this.ghostVisible = false;
    this.lastHit = undefined;
  }

  private placeCurrent(): void {
    if (!this.placementMode || this.lastHit === undefined || !this.lastHit.valid) return;
    const artwork: ArtworkEntry | undefined =
      this.getAllArtworks().find(a => a.id === this.selectedArtworkId);
    if (artwork === undefined) return;
    const p: Placement = {
      slotId: 'c_' + Date.now().toString(), artworkId: artwork.id,
      artworkTitle: artwork.titleZh, scale: 0.9, offsetX: 0, offsetY: 0,
      worldX: this.lastHit.worldX, worldY: this.lastHit.worldY, worldZ: this.lastHit.worldZ
    };
    this.placements = this.placements.concat([p]);
    // Keep ghost active for continued placement
    this.lastHit = undefined;
    this.ghostVisible = false;
  }

  private removePlacement(slotId: string): void {
    const filtered: Placement[] = [];
    for (const p of this.placements) { if (p.slotId !== slotId) filtered.push(p); }
    this.placements = filtered;
    if (this.placements.length === 0 && !this.placementMode) {
      this.stopFrameLoop();
    }
  }

  private getAllArtworks(): ArtworkEntry[] { return PRESET_ARTWORKS.concat(this.userArtworks); }

  private getSceneName(): string {
    for (const s of PRESET_SCENES) { if (s.id === this.currentSceneId) return s.name; }
    return '选择场景';
  }

  private switchScene(sceneId: string): void {
    if (sceneId === this.currentSceneId) { this.showScenePicker = false; return; }
    this.currentSceneId = sceneId;
    this.walls = getWallsForScene(sceneId);
    this.showScenePicker = false;
    this.loadScene();
  }

  private exportData(): void {
    try {
      const data: ExportData = {
        sceneId: this.currentSceneId, exportedAt: new Date().toISOString(),
        placements: this.placements
      };
      const context = getContext(this);
      const path: string = context.filesDir + '/ex_' + Date.now().toString() + '.json';
      const file: fileIo.File = fileIo.openSync(
        path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC
      );
      fileIo.writeSync(file.fd, JSON.stringify(data));
      fileIo.closeSync(file);
      hilog.info(DOMAIN, 'Editor', 'exported: %{public}s', path);
    } catch (e) { this.errorMsg = 'export failed'; }
  }

  private async pickAndAddArtwork(): Promise<void> {
    try {
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await photoPicker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE, maxSelectNumber: 1
      });
      const uris: string[] = result.photoUris;
      if (uris.length === 0) return;
      const na: ArtworkEntry = {
        id: 'u_' + Date.now().toString(),
        titleZh: '作品' + (this.userArtworks.length + 1).toString(),
        titleEn: 'Artwork', artist: 'Unknown', imageUri: uris[0], type: 'painting'
      };
      this.userArtworks = this.userArtworks.concat([na]);
      this.selectedArtworkId = na.id;
      this.placementMode = true;
    } catch (e) { this.errorMsg = 'upload failed'; }
  }

  // ==================== BUILD ====================

  build() {
    Stack() {
      Column().width('100%').height('100%').backgroundColor('#0a0a1a')

      // --- 3D Scene ---
      if (this.sceneReady && this.sceneInstance !== undefined) {
        Component3D({ scene: this.sceneInstance })
          .width('100%').height('100%').backgroundColor('#0a0a1a')
          .opacity(this.sceneOpacity)
          .gesture(
            PanGesture({ fingers: 1 })
              .onActionStart(() => { this.fps.onPanStart(); })
              .onActionUpdate((e: GestureEvent) => {
                if (!this.showScenePicker && !this.showFineTune) {
                  this.fps.onPanUpdate(e.offsetX, e.offsetY);
                }
              })
              .onActionEnd(() => { this.fps.onPanEnd(); })
          )
      }

      // --- PLACED ARTWORK OVERLAYS (always visible when placements exist) ---
      this.buildPlacedOverlays()

      // --- CROSSHAIR ---
      if (this.placementMode) {
        Text('＋')
          .fontSize(30).fontColor('#CCd4b678')
          .position({ x: '50%', y: '50%' }).markAnchor({ x: 0, y: 0 })
          .hitTestBehavior(HitTestMode.Transparent)
      }

      // --- GHOST PREVIEW ---
      if (this.placementMode && this.ghostVisible && this.ghostW > 0) {
        Column()
          .width(this.ghostW).height(this.ghostH)
          .backgroundColor('#18d4b678')
          .border({ width: 2, color: this.ghostValid ? '#BBd4b678' : '#BBff4444' })
          .position({ x: this.ghostX, y: this.ghostY })
          .hitTestBehavior(HitTestMode.Transparent)
      }

      // --- PLACE BUTTON ---
      if (this.placementMode && this.ghostVisible && this.ghostValid) {
        Button('放置', { type: ButtonType.Capsule })
          .fontSize(16).height(44).padding({ left: 24, right: 24 })
          .backgroundColor('#d4b678').fontColor('#0a0a1a')
          .position({ x: '50%', y: '58%' }).markAnchor({ x: 0, y: 0 })
          .onClick(() => { this.placeCurrent(); })
      }

      // --- TOP-LEFT: back + scene ---
      Row({ space: 8 }) {
        Button('←', { type: ButtonType.Capsule })
          .fontSize(13).height(30).width(36)
          .backgroundColor('#1a1a2e60').fontColor('#ffffff')
          .onClick(() => { router.back(); })
        Button(this.getSceneName() + ' ▾', { type: ButtonType.Capsule })
          .fontSize(11).height(30)
          .backgroundColor('#1a1a2e60').fontColor('#d4b678')
          .borderColor('#d4b67844').borderWidth(1)
          .onClick(() => { this.showScenePicker = !this.showScenePicker; })
      }
      .position({ x: 12, y: 12 })

      // --- TOP-RIGHT: count + export ---
      Row({ space: 6 }) {
        Text(this.placements.length.toString() + '幅')
          .fontSize(12).fontColor('#b9a57a')
        Button('导出', { type: ButtonType.Capsule })
          .fontSize(11).height(28)
          .backgroundColor('#1a1a2e60').fontColor('#b9a57a')
          .borderColor('#d4b67844').borderWidth(1)
          .onClick(() => { this.exportData(); })
      }
      .position({ x: '100%', y: 12 }).markAnchor({ x: 105, y: 0 })

      // --- CANCEL (placement mode only) ---
      if (this.placementMode) {
        Button('✕', { type: ButtonType.Capsule })
          .fontSize(12).height(30).width(36)
          .backgroundColor('#1a1a2e60').fontColor('#8a8a9a')
          .position({ x: 12, y: 50 })
          .onClick(() => { this.cancelPlacement(); })
      }

      // --- SCENE PICKER ---
      if (this.showScenePicker) {
        this.buildScenePicker()
      }

      // --- JOYSTICK ---
      Joystick({
        onInput: (x: number, y: number) => { this.fps.setMoveInput(x, y); }
      })
        .position({ x: 32, y: '100%' }).markAnchor({ x: 0, y: 148 })

      // --- HOTBAR (centered, Minecraft style) ---
      if (this.showHotbar) {
        Row({ space: 6 }) {
          // upload button
          Column({ space: 1 }) {
            Row() {
              Text('+').fontSize(16).fontColor('#d4b678')
            }
            .width(42).height(34)
            .backgroundColor('#1a1a2e77').borderColor('#d4b67855').borderWidth(1).borderRadius(6)
            .borderStyle(BorderStyle.Dashed)
            .justifyContent(FlexAlign.Center)
          }
          .onClick(() => { this.pickAndAddArtwork(); })

          ForEach(this.getAllArtworks(), (art: ArtworkEntry) => {
            Column({ space: 1 }) {
              Row() {
                Text(art.titleZh.substring(0, 2))
                  .fontSize(11)
                  .fontColor(this.selectedArtworkId === art.id ? '#0a0a1a' : '#d4b678')
              }
              .width(42).height(34)
              .backgroundColor(
                this.selectedArtworkId === art.id ? '#d4b678' : '#1a1a2e77'
              )
              .borderColor(
                this.selectedArtworkId === art.id ? '#d4b678' : '#4a4a5a44'
              )
              .borderWidth(1).borderRadius(6)
              .justifyContent(FlexAlign.Center)
            }
            .onClick(() => { this.selectArtwork(art); })
          }, (art: ArtworkEntry) => art.id)
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 6 })
        .backgroundColor('#1a1a2e55')
        .borderRadius(8)
        .position({ x: '50%', y: '100%' }).markAnchor({ x: 0, y: 46 })
      }

      // --- FINE-TUNE panel ---
      if (this.showFineTune) {
        this.buildFineTuneOverlay()
      }

      // --- LOADING ---
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

  @Builder
  buildPlacedOverlays() {
    ForEach(this.placements, (p: Placement) => {
      Column()
        .width(this.placedW(p)).height(this.placedH(p))
        .backgroundColor('#10d4b678')
        .border({ width: 1.5, color: '#77d4b678' })
        .position({ x: this.placedX(p), y: this.placedY(p) })
        .hitTestBehavior(HitTestMode.Transparent)
    }, (p: Placement) => p.slotId)
  }

  private placedW(p: Placement): number {
    let wx: number = 0; let wy: number = 0; let wz: number = 0;
    if (p.worldX !== undefined) { wx = p.worldX; wy = p.worldY ?? 0; wz = p.worldZ ?? 0; }
    return this.computeGhostAt(wx, wy, wz).w;
  }
  private placedH(p: Placement): number {
    let wx: number = 0; let wy: number = 0; let wz: number = 0;
    if (p.worldX !== undefined) { wx = p.worldX; wy = p.worldY ?? 0; wz = p.worldZ ?? 0; }
    return this.computeGhostAt(wx, wy, wz).h;
  }
  private placedX(p: Placement): number {
    let wx: number = 0; let wy: number = 0; let wz: number = 0;
    if (p.worldX !== undefined) { wx = p.worldX; wy = p.worldY ?? 0; wz = p.worldZ ?? 0; }
    return this.computeGhostAt(wx, wy, wz).x;
  }
  private placedY(p: Placement): number {
    let wx: number = 0; let wy: number = 0; let wz: number = 0;
    if (p.worldX !== undefined) { wx = p.worldX; wy = p.worldY ?? 0; wz = p.worldZ ?? 0; }
    return this.computeGhostAt(wx, wy, wz).y;
  }

  @Builder
  buildScenePicker() {
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

  @Builder
  buildFineTuneOverlay() {
    Column() {
      Column({ space: 6 }) {
        Text('已放置作品').fontSize(14).fontColor('#f5e6c8').fontWeight(FontWeight.Medium)
        ForEach(this.placements, (p: Placement) => {
          Row({ space: 6 }) {
            Text(p.artworkTitle).fontSize(11).fontColor('#d4b678').width(120)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Button('✕', { type: ButtonType.Capsule }).fontSize(10).height(24).width(30)
              .backgroundColor('#3a2020').fontColor('#ff6b6b')
              .onClick(() => { this.removePlacement(p.slotId); })
          }.width('100%').padding({ left: 6, right: 6, top: 3, bottom: 3 })
        }, (p: Placement) => p.slotId)
        Button('关闭', { type: ButtonType.Capsule }).fontSize(12).height(30)
          .backgroundColor('#1a1a2e').fontColor('#8a8a9a')
          .onClick(() => { this.showFineTune = false; })
      }.width(220).padding(10)
      .backgroundColor('#F01a1a2e').borderColor('#88d4b678').borderWidth(1).borderRadius(12)
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .backgroundColor('#00000044')
    .position({ x: 0, y: 0 })
  }
}
