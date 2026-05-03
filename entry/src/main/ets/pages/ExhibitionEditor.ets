import { router } from '@kit.ArkUI';
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

interface RGBA { r: number; g: number; b: number; a: number; }
interface ExportData { sceneId: string; exportedAt: string; placements: Placement[]; }
interface ScreenPoint { x: number; y: number; visible: boolean; }
interface GhostRect { x: number; y: number; w: number; h: number; }

const MAX_RAY_RANGE = 5.0;
const PAINTING_W = 1.2;
const PAINTING_H = 0.9;

@Entry
@Component
struct ExhibitionEditor {
  @State private sceneReady: boolean = false;
  @State private errorMsg: string = '';
  @State private loadingOpacity: number = 1;
  @State private sceneOpacity: number = 0;
  @State private selectedArtworkId: string = '';
  @State private placements: Placement[] = [];
  @State private placementMode: boolean = false;
  @State private userArtworks: ArtworkEntry[] = [];
  @State private currentSceneId: string = 'white_cube';
  @State private showScenePicker: boolean = false;
  @State private showFineTune: boolean = false;
  @State private showHotbar: boolean = true;
  @State private ghostValid: boolean = false;
  @State private ghostX: number = 0;
  @State private ghostY: number = 0;
  @State private ghostW: number = 0;
  @State private ghostH: number = 0;

  private sceneInstance: Scene | undefined = undefined;
  private mainCamera: Camera | undefined = undefined;
  private fps: FirstPersonCameraController = new FirstPersonCameraController(
    { id: 's', name: 's', position: { x: 0, y: 1.65, z: 3.5 }, yaw: 0, pitch: 0 }
  );
  private walls: WallPlane[] = WHITE_CUBE_WALLS;
  private lastHit: WallHit | undefined = undefined;

  async aboutToAppear(): Promise<void> {
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
      const emptyColliders: AABB2[] = [];
      this.fps.setColliders(emptyColliders);
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

  aboutToDisappear(): void { this.fps.detach(); }

  // ==================== FRAME UPDATE ====================

  private onFrame(): void {
    if (!this.placementMode) return;
    const yaw: number = this.fps.getYaw();
    const pitch: number = this.fps.getPitch();
    const cp: number = Math.cos(pitch);
    const dx: number = Math.sin(yaw) * cp;
    const dy: number = -Math.sin(pitch);
    const dz: number = -Math.cos(yaw) * cp;

    const placedList: PlacedArtwork[] = [];
    for (const p of this.placements) {
      let wx: number = 0; let wy: number = 0; let wz: number = 0;
      if (p.worldX !== undefined) { wx = p.worldX; wy = p.worldY ?? 0; wz = p.worldZ ?? 0; }
      else {
        const slot: ParsedSlot | undefined = this.findSlot(p.slotId);
        wx = slot !== undefined ? slot.positionX : 0;
        wy = slot !== undefined ? slot.positionY : 0;
        wz = slot !== undefined ? slot.positionZ : 0;
      }
      placedList.push({ worldX: wx, worldY: wy, worldZ: wz, width: PAINTING_W, height: PAINTING_H });
    }

    const hit: WallHit | undefined = detectWallHit(
      this.fps.getPositionX(), this.fps.getPositionY(), this.fps.getPositionZ(),
      dx, dy, dz, this.walls, placedList, MAX_RAY_RANGE
    );
    this.lastHit = hit;

    if (hit === undefined) {
      this.ghostValid = false; return;
    }

    this.ghostValid = hit.valid;
    const g: GhostRect = this.computeGhost(
      hit.worldX, hit.worldY, hit.worldZ,
      this.fps.getPositionX(), this.fps.getPositionY(), this.fps.getPositionZ(),
      yaw, pitch
    );
    this.ghostX = g.x; this.ghostY = g.y; this.ghostW = g.w; this.ghostH = g.h;
  }

  private computeGhost(
    wx: number, wy: number, wz: number,
    cx: number, cy: number, cz: number,
    yaw: number, pitch: number
  ): GhostRect {
    // Project center
    const c: ScreenPoint = this.project(wx, wy, wz, cx, cy, cz, yaw, pitch);
    // Project right edge of painting
    const yr: number = Math.sin(yaw);
    const xr: number = -Math.cos(yaw); // right direction along wall XZ
    const right: ScreenPoint = this.project(
      wx + xr * PAINTING_W / 2, wy, wz + yr * PAINTING_W / 2,
      cx, cy, cz, yaw, pitch
    );
    const top: ScreenPoint = this.project(
      wx, wy + PAINTING_H / 2, wz, cx, cy, cz, yaw, pitch
    );
    const hw: number = Math.abs(right.x - c.x) * 2;
    const hh: number = Math.abs(c.y - top.y) * 2;
    const result: GhostRect = {
      x: c.x - hw / 2, y: c.y - hh / 2, w: hw > 0 ? hw : 80, h: hh > 0 ? hh : 60
    };
    return result;
  }

  private project(
    wx: number, wy: number, wz: number,
    cx: number, cy: number, cz: number,
    yaw: number, pitch: number
  ): ScreenPoint {
    const dx: number = wx - cx; const dy: number = wy - cy; const dz: number = wz - cz;
    const cosY: number = Math.cos(-yaw); const sinY: number = Math.sin(-yaw);
    const cosP: number = Math.cos(-pitch); const sinP: number = Math.sin(-pitch);
    const rx: number = dx * cosY - dz * sinY;
    const rz: number = dx * sinY + dz * cosY;
    const ry: number = dy * cosP - rz * sinP;
    const rz2: number = dy * sinP + rz * cosP;
    if (rz2 <= 0.01) {
      const r: ScreenPoint = { x: -200, y: -200, visible: false };
      return r;
    }
    const sw: number = 1920; const sh: number = 1080;
    const fovY: number = 65 * Math.PI / 180;
    const halfH: number = Math.tan(fovY / 2);
    const halfW: number = halfH * (sw / sh);
    const sx: number = (rx / rz2) / halfW;
    const sy: number = -(ry / rz2) / halfH;
    const r: ScreenPoint = {
      x: (sx + 1) / 2 * sw, y: (sy + 1) / 2 * sh,
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
    this.ghostValid = false;
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
    this.ghostValid = false;
    this.lastHit = undefined;
  }

  private removePlacement(slotId: string): void {
    const filtered: Placement[] = [];
    for (const p of this.placements) { if (p.slotId !== slotId) filtered.push(p); }
    this.placements = filtered;
  }

  private getAllArtworks(): ArtworkEntry[] { return PRESET_ARTWORKS.concat(this.userArtworks); }

  private findSlot(id: string): ParsedSlot | undefined {
    for (const s of getPresetSlots(this.currentSceneId)) { if (s.slotId === id) return s; }
    return undefined;
  }

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

  // ==================== EXPORT ====================

  private exportData(): void {
    try {
      const data: ExportData = {
        sceneId: this.currentSceneId, exportedAt: new Date().toISOString(), placements: this.placements
      };
      const context = getContext(this);
      const path: string = context.filesDir + '/ex_' + Date.now().toString() + '.json';
      const file: fileIo.File = fileIo.openSync(
        path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC
      );
      fileIo.writeSync(file.fd, JSON.stringify(data));
      fileIo.closeSync(file);
      hilog.info(DOMAIN, 'Editor', 'exported to: %{public}s', path);
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

      // 3D Scene
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

      // --- CROSSHAIR ---
      if (this.placementMode) {
        Text('＋')
          .fontSize(26).fontColor('#d4b67888')
          .position({ x: '50%', y: '50%' }).markAnchor({ x: 0, y: 0 })
          .hitTestBehavior(HitTestMode.Transparent)
      }

      // --- GHOST PREVIEW: gold-framed transparent rectangle ---
      if (this.placementMode && this.lastHit !== undefined && this.ghostW > 0) {
        Column()
          .width(this.ghostW).height(this.ghostH)
          .backgroundColor(this.ghostValid ? '#18d4b678' : '#18ff4444')
          .border({ width: 2, color: this.ghostValid ? '#CCd4b678' : '#CCff4444' })
          .position({ x: this.ghostX, y: this.ghostY })
          .hitTestBehavior(HitTestMode.Transparent)
      }

      // --- TOP: floating buttons (no background strip) ---
      Row({ space: 10 }) {
        Button('←', { type: ButtonType.Capsule })
          .fontSize(14).height(34).width(40)
          .backgroundColor('#1a1a2e88').fontColor('#ffffff')
          .onClick(() => { router.back(); })

        Button(this.getSceneName() + ' ▾', { type: ButtonType.Capsule })
          .fontSize(12).height(34)
          .backgroundColor('#1a1a2e88').fontColor('#d4b678')
          .borderColor('#d4b67844').borderWidth(1)
          .onClick(() => { this.showScenePicker = !this.showScenePicker; })
      }
      .position({ x: 14, y: 14 })

      // Top-right: count + export
      Row({ space: 8 }) {
        Text('已放置 ' + this.placements.length.toString())
          .fontSize(12).fontColor('#b9a57a')
        Button('导出', { type: ButtonType.Capsule })
          .fontSize(11).height(30)
          .backgroundColor('#1a1a2e88').fontColor('#b9a57a')
          .borderColor('#d4b67844').borderWidth(1)
          .onClick(() => { this.exportData(); })
      }
      .position({ x: '100%', y: 14 }).markAnchor({ x: 10, y: 0 })

      // --- PLACE BUTTON (near center, when ghost valid) ---
      if (this.placementMode && this.ghostValid) {
        Button('放置', { type: ButtonType.Capsule })
          .fontSize(16).height(44).padding({ left: 24, right: 24 })
          .backgroundColor('#d4b678').fontColor('#0a0a1a')
          .position({ x: '50%', y: '62%' }).markAnchor({ x: 0, y: 0 })
          .onClick(() => { this.placeCurrent(); })
      }

      // --- CANCEL PLACEMENT ---
      if (this.placementMode) {
        Row({ space: 8 }) {
          Button('✕ 取消', { type: ButtonType.Capsule })
            .fontSize(12).height(32)
            .backgroundColor('#1a1a2e88').fontColor('#8a8a9a')
            .onClick(() => { this.cancelPlacement(); })
        }
        .position({ x: 14, y: 56 })
      }

      // --- SCENE PICKER ---
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

      // --- JOYSTICK ---
      Joystick({
        onInput: (x: number, y: number) => { this.fps.setMoveInput(x, y); }
      })
        .position({ x: 32, y: '100%' }).markAnchor({ x: 0, y: 140 })

      // --- HOTBAR: centered at bottom (Minecraft style) ---
      if (this.showHotbar) {
        Row({ space: 8 }) {
          // upload
          Column({ space: 2 }) {
            Row() {
              Text('+').fontSize(18).fontColor('#d4b678')
            }
            .width(44).height(36)
            .backgroundColor('#1a1a2e88').borderColor('#d4b67866').borderWidth(1).borderRadius(6)
            .justifyContent(FlexAlign.Center)
          }
          .onClick(() => { this.pickAndAddArtwork(); })

          ForEach(this.getAllArtworks(), (art: ArtworkEntry) => {
            Column({ space: 1 }) {
              Row() {
                Text(art.titleZh.substring(0, 2))
                  .fontSize(12)
                  .fontColor(this.selectedArtworkId === art.id ? '#0a0a1a' : '#d4b678')
              }
              .width(44).height(36)
              .backgroundColor(
                this.selectedArtworkId === art.id ? '#d4b678' : '#1a1a2e88'
              )
              .borderColor(
                this.selectedArtworkId === art.id ? '#d4b678' : '#4a4a5a66'
              )
              .borderWidth(1).borderRadius(6)
              .justifyContent(FlexAlign.Center)
            }
            .onClick(() => { this.selectArtwork(art); })
          }, (art: ArtworkEntry) => art.id)
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor('#1a1a2e66')
        .borderRadius(10)
        .position({ x: '50%', y: '100%' }).markAnchor({ x: 0, y: 52 })
      }

      // --- FINE TUNE panel ---
      if (this.showFineTune) {
        Column() {
          Column({ space: 8 }) {
            Text('已放置作品').fontSize(14).fontColor('#f5e6c8').fontWeight(FontWeight.Medium)
            ForEach(this.placements, (p: Placement) => {
              Row({ space: 8 }) {
                Text(p.artworkTitle).fontSize(12).fontColor('#d4b678').width(100)
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Button('✕', { type: ButtonType.Capsule })
                  .fontSize(10).height(26).width(32)
                  .backgroundColor('#3a2020').fontColor('#ff6b6b')
                  .onClick(() => { this.removePlacement(p.slotId); })
              }
              .width('100%').padding({ left: 8, right: 8, top: 4, bottom: 4 })
            }, (p: Placement) => p.slotId)
            Button('关闭', { type: ButtonType.Capsule })
              .fontSize(12).height(30)
              .backgroundColor('#1a1a2e').fontColor('#8a8a9a')
              .onClick(() => { this.showFineTune = false; })
          }
          .width(240).padding(12)
          .backgroundColor('#F01a1a2e').borderColor('#88d4b678').borderWidth(1).borderRadius(12)
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .backgroundColor('#00000044')
        .position({ x: 0, y: 0 })
      }

      // --- Loading ---
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
}
