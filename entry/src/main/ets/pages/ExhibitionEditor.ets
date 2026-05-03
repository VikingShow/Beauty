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
const FRAME_MS = 16;
const MAX_RAY_RANGE = 5.0;
const PAINTING_W = 1.2;
const PAINTING_H = 0.9;

interface RGBA { r: number; g: number; b: number; a: number; }
interface ExportData { sceneId: string; exportedAt: string; placements: Placement[]; }
interface ScreenPoint { x: number; y: number; visible: boolean; }
interface GhostRect { x: number; y: number; w: number; h: number; }

// glTF JSON substructures (minimal fields used in rebuild)
interface GltfBuffer { uri: string; byteLength: number; }
interface GltfBufferView { buffer: number; byteOffset: number; byteLength: number; target?: number; }
interface GltfAccessor { bufferView: number; componentType: number; count: number; type: string; }
interface GltfPrimitive { attributes: Record<string, number>; indices: number; material: number; }
interface GltfMesh { name: string; primitives: GltfPrimitive[]; }
interface GltfNode { mesh?: number; name?: string; translation?: number[]; rotation?: number[]; extras?: Record<string, Object>; }
interface GltfScene { nodes: number[]; }
interface GltfImage { uri: string; }
interface GltfTexture { source: number; sampler: number; }
interface GltfMaterial { name: string; pbrMetallicRoughness: Record<string, Object>; doubleSided: boolean; alphaMode?: string; }
interface GltfRoot {
  asset: Record<string, string>;
  scene: number;
  scenes: GltfScene[];
  nodes: GltfNode[];
  meshes: GltfMesh[];
  materials: GltfMaterial[];
  textures: GltfTexture[];
  images: GltfImage[];
  buffers: GltfBuffer[];
  bufferViews: GltfBufferView[];
  accessors: GltfAccessor[];
}

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

  // -- UI --
  @State private showScenePicker: boolean = false;
  @State private showFineTune: boolean = false;
  @State private showHotbar: boolean = true;
  @State private overlayCount: number = 0;

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
  private cachedOverlays: GhostRect[] = [];
  private sandboxScenePath: string = '';
  private sandboxRegistered: boolean = false;

  async aboutToAppear(): Promise<void> {
    this.walls = getWallsForScene(this.currentSceneId);
    await this.loadScene();
  }

  private getSceneResource(): Resource {
    if (this.currentSceneId === 'salon_carre') return $rawfile('gltf/salon_carre/scene.gltf');
    return $rawfile('gltf/white_cube/scene.gltf');
  }

  private async loadScene(keepPlacements?: boolean): Promise<void> {
    this.sceneReady = false; this.sceneOpacity = 0; this.loadingOpacity = 1;
    if (keepPlacements !== true) {
      this.placements = [];
    }
    this.placementMode = false; this.fps.detach();
    this.stopFrameLoop();

    // Try sandbox scene first, fall back to rawfile
    let scene: Scene;
    let source: string = 'rawfile';
    try {
      if (this.sandboxScenePath !== '') {
        hilog.info(DOMAIN, 'Editor', 'Trying sandbox: %{public}s', this.sandboxScenePath);
        scene = await Scene.load(this.sandboxScenePath);
        source = 'sandbox';
      } else {
        scene = await Scene.load(this.getSceneResource());
      }
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.info(DOMAIN, 'Editor', 'Sandbox load failed: %{public}s, falling back', err.message ?? '');
      scene = await Scene.load(this.getSceneResource());
      this.sandboxScenePath = ''; // clear so we don't keep failing
    }
    hilog.info(DOMAIN, 'Editor', 'Scene loaded from: %{public}s', source);

    try {
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

  // ==================== SANDBOX glTF REBUILD ====================

  private async rebuildSceneInSandbox(): Promise<void> {
    try {
      hilog.info(DOMAIN, 'Editor', 'rebuild: START');
      const context = getContext(this);

      if (!this.sandboxRegistered) {
        const rc = Scene.getDefaultRenderContext();
        if (rc !== undefined && rc !== null) {
          const ok: boolean = rc.registerResourcePath('sandbox', context.filesDir);
          hilog.info(DOMAIN, 'Editor', 'registerResourcePath: %{public}s', ok ? 'OK' : 'FAIL');
          this.sandboxRegistered = ok;
        }
      }

      const basePath: string = this.currentSceneId === 'salon_carre'
        ? 'gltf/salon_carre/scene.gltf' : 'gltf/white_cube/scene.gltf';
      hilog.info(DOMAIN, 'Editor', 'rebuild: reading rawfile %{public}s', basePath);
      const rm = context.resourceManager;
      const rawFd = rm.getRawFdSync(basePath);
      const fd: number = rawFd.fd;
      const fileLen: number = rawFd.length;
      const rawBytes = new Uint8Array(fileLen);
      fileIo.readSync(fd, rawBytes);
      fileIo.closeSync(fd);
      const rawText = this.bytesToString(rawBytes);
      const gltf: GltfRoot = JSON.parse(rawText) as GltfRoot;
      hilog.info(DOMAIN, 'Editor', 'rebuild: glTF parsed, buffers=%{public}d', gltf.buffers.length);

      const buf0: GltfBuffer = gltf.buffers[0];
      const b64: string = buf0.uri.replace('data:application/octet-stream;base64,', '');
      const binBytes: Uint8Array = this.base64Decode(b64);
      const binLen: number = binBytes.length;
      hilog.info(DOMAIN, 'Editor', 'rebuild: base64 decoded, binLen=%{public}d', binLen);

      // Generate painting quads
      const paintings = this.placements.filter(p => p.worldX !== undefined);
      const quadCount: number = paintings.length;
      hilog.info(DOMAIN, 'Editor', 'rebuild: quadCount=%{public}d, placements=%{public}d',
        quadCount, this.placements.length);
      const totalNewVerts: number = quadCount * 4;
      const totalNewIndices: number = quadCount * 6;

      if (quadCount === 0) {
        hilog.info(DOMAIN, 'Editor', 'rebuild: no quads to add, skipping');
        return;
      }

      const posData = new Float32Array(totalNewVerts * 3);
      const normData = new Float32Array(totalNewVerts * 3);
      const uvData = new Float32Array(totalNewVerts * 2);
      const idxData = new Uint16Array(totalNewIndices);
      const uvPattern = new Float32Array([0, 0, 1, 0, 1, 1, 0, 1]);

      for (let qi = 0; qi < quadCount; qi++) {
        const p = paintings[qi];
        const wx: number = p.worldX!; const wy: number = p.worldY!; const wz: number = p.worldZ!;
        const hw: number = PAINTING_W / 2; const hh: number = PAINTING_H / 2;
        let nx: number = 0; let nz: number = 0;
        if (Math.abs(wz + 5.0) < 0.1) { nx = 0; nz = 1; }
        else if (Math.abs(wz - 5.0) < 0.1) { nx = 0; nz = -1; }
        else if (Math.abs(wx - 7.5) < 0.1) { nx = -1; nz = 0; }
        else if (Math.abs(wx + 7.5) < 0.1) { nx = 1; nz = 0; }
        const rxx: number = nz; const rz: number = -nx;
        const epsilon: number = 0.01;
        const ox: number = wx + nx * epsilon;
        const oz: number = wz + nz * epsilon;
        const vi: number = qi * 4;
        posData[(vi+0)*3+0]=ox+rxx*(-hw); posData[(vi+0)*3+1]=wy-hh; posData[(vi+0)*3+2]=oz+rz*(-hw);
        posData[(vi+1)*3+0]=ox+rxx*(-hw); posData[(vi+1)*3+1]=wy+hh; posData[(vi+1)*3+2]=oz+rz*(-hw);
        posData[(vi+2)*3+0]=ox+rxx*(hw);  posData[(vi+2)*3+1]=wy+hh; posData[(vi+2)*3+2]=oz+rz*(hw);
        posData[(vi+3)*3+0]=ox+rxx*(hw);  posData[(vi+3)*3+1]=wy-hh; posData[(vi+3)*3+2]=oz+rz*(hw);
        for (let v = 0; v < 4; v++) {
          normData[(vi+v)*3+0]=nx; normData[(vi+v)*3+1]=0; normData[(vi+v)*3+2]=nz;
          uvData[(vi+v)*2+0]=uvPattern[v*2]; uvData[(vi+v)*2+1]=uvPattern[v*2+1];
        }
        const ii: number = qi * 6;
        idxData[ii+0]=vi; idxData[ii+1]=vi+1; idxData[ii+2]=vi+2;
        idxData[ii+3]=vi; idxData[ii+4]=vi+2; idxData[ii+5]=vi+3;
      }

      const posBytes = new Uint8Array(posData.buffer);
      const normBytes = new Uint8Array(normData.buffer);
      const uvBytes = new Uint8Array(uvData.buffer);
      const idxBytes = new Uint8Array(idxData.buffer);
      const posP = this.padTo4(posBytes); const normP = this.padTo4(normBytes);
      const uvP = this.padTo4(uvBytes); const idxP = this.padTo4(idxBytes);

      const bvCount: number = gltf.bufferViews.length;
      const acCount: number = gltf.accessors.length;
      const off1: number = binLen + posP.length;
      const off2: number = off1 + normP.length;
      const off3: number = off2 + uvP.length;

      const newBVs: GltfBufferView[] = [];
      const bv: GltfBufferView = { buffer: 0, byteOffset: binLen, byteLength: posP.length, target: 34962 };
      newBVs.push(bv);
      const bv2: GltfBufferView = { buffer: 0, byteOffset: off1, byteLength: normP.length, target: 34962 };
      newBVs.push(bv2);
      const bv3: GltfBufferView = { buffer: 0, byteOffset: off2, byteLength: uvP.length, target: 34962 };
      newBVs.push(bv3);
      const bv4: GltfBufferView = { buffer: 0, byteOffset: off3, byteLength: idxP.length, target: 34963 };
      newBVs.push(bv4);

      const ac: GltfAccessor = { bufferView: bvCount, componentType: 5126, count: totalNewVerts, type: 'VEC3' };
      const ac2: GltfAccessor = { bufferView: bvCount+1, componentType: 5126, count: totalNewVerts, type: 'VEC3' };
      const ac3: GltfAccessor = { bufferView: bvCount+2, componentType: 5126, count: totalNewVerts, type: 'VEC2' };
      const ac4: GltfAccessor = { bufferView: bvCount+3, componentType: 5123, count: totalNewIndices, type: 'SCALAR' };
      const newACs: GltfAccessor[] = [ac, ac2, ac3, ac4];

      const matCount: number = gltf.materials.length;

      // Use solid gold color material (no texture dependency for first test)
      const pbrObj: Record<string, Object> = {
        'baseColorFactor': [0.83, 0.72, 0.47, 1.0],  // #d4b678 gold in RGBA
        'metallicFactor': 0.0, 'roughnessFactor': 0.6
      };
      const newMat: GltfMaterial = {
        name: 'ArtworkPaint', pbrMetallicRoughness: pbrObj, doubleSided: true
      };
      const attrObj: Record<string, number> = {
        'POSITION': acCount, 'NORMAL': acCount+1, 'TEXCOORD_0': acCount+2
      };
      const prim: GltfPrimitive = { attributes: attrObj, indices: acCount+3, material: matCount };
      const newMesh: GltfMesh = { name: 'PlacedArtworks', primitives: [prim] };
      const newNode: GltfNode = { mesh: gltf.meshes.length, name: 'PlacedArtworksNode' };

      gltf.bufferViews = gltf.bufferViews.concat(newBVs);
      gltf.accessors = gltf.accessors.concat(newACs);
      gltf.materials = gltf.materials.concat([newMat]);
      gltf.meshes = gltf.meshes.concat([newMesh]);
      gltf.nodes = gltf.nodes.concat([newNode]);
      gltf.scenes[0].nodes.push(gltf.nodes.length - 1);

      // Re-encode buffer
      const newBin = new Uint8Array(binLen + posP.length + normP.length + uvP.length + idxP.length);
      newBin.set(binBytes, 0);
      newBin.set(posP, binLen);
      newBin.set(normP, off1);
      newBin.set(uvP, off2);
      newBin.set(idxP, off3);
      const newB64: string = this.base64Encode(newBin);
      gltf.buffers[0] = {
        uri: 'data:application/octet-stream;base64,' + newB64,
        byteLength: newBin.length
      };

      // Write to sandbox
      const sandboxPath: string = context.filesDir + '/scene_modified.gltf';
      const jsonStr: string = JSON.stringify(gltf);
      const file: fileIo.File = fileIo.openSync(sandboxPath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, jsonStr);
      fileIo.closeSync(file.fd);

      const protocol: string = this.sandboxRegistered ? 'sandbox://' : '';
      this.sandboxScenePath = protocol + 'scene_modified.gltf';
      hilog.info(DOMAIN, 'Editor', 'rebuild: written %{public}d bytes, path=%{public}s, now reloading',
        jsonStr.length, sandboxPath);

      await this.loadScene(true);  // keep placements for future rebuilds
      hilog.info(DOMAIN, 'Editor', 'rebuild: DONE reload');
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, 'Editor', 'rebuild EXCEPTION: %{public}s', JSON.stringify(e));
      hilog.error(DOMAIN, 'Editor', 'rebuild EXCEPTION message: %{public}s', err.message ?? 'no message');
      this.errorMsg = '重建失败: ' + (err.message ?? 'unknown');
    }
  }

  private padTo4(arr: Uint8Array): Uint8Array {
    const rem: number = arr.length % 4;
    if (rem === 0) return arr;
    const padded = new Uint8Array(arr.length + (4 - rem));
    padded.set(arr);
    return padded;
  }

  private bytesToString(bytes: Uint8Array): string {
    let str: string = '';
    for (let i = 0; i < bytes.length; i++) {
      str += String.fromCharCode(bytes[i]);
    }
    return str;
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
    if (!this.placementMode && this.placements.length === 0) return;
    const yaw: number = this.fps.getYaw();
    const pitch: number = this.fps.getPitch();
    const cp: number = Math.cos(pitch);
    const dx: number = Math.sin(yaw) * cp;
    const dy: number = -Math.sin(pitch);
    const dz: number = -Math.cos(yaw) * cp;

    // Ghost preview
    if (this.placementMode) {
      const placedList: PlacedArtwork[] = [];
      for (const p of this.placements) {
        let wx = 0; let wy = 0; let wz = 0;
        if (p.worldX !== undefined) { wx = p.worldX; wy = p.worldY ?? 0; wz = p.worldZ ?? 0; }
        placedList.push({ worldX: wx, worldY: wy, worldZ: wz, width: PAINTING_W, height: PAINTING_H });
      }
      const hit: WallHit | undefined = detectWallHit(
        this.fps.getPositionX(), this.fps.getPositionY(), this.fps.getPositionZ(),
        dx, dy, dz, this.walls, placedList, MAX_RAY_RANGE
      );
      this.lastHit = hit;
      if (hit !== undefined) {
        this.ghostValid = hit.valid;
        const g: GhostRect = this.computeGhostAt(hit.worldX, hit.worldY, hit.worldZ);
        this.ghostX = g.x; this.ghostY = g.y; this.ghostW = g.w; this.ghostH = g.h;
        this.ghostVisible = true;
      } else {
        this.ghostVisible = false;
      }
    } else {
      this.ghostVisible = false;
    }
  }

  // ==================== PROJECTION ====================

  private computeGhostAt(wx: number, wy: number, wz: number): GhostRect {
    const cx: number = this.fps.getPositionX();
    const cy: number = this.fps.getPositionY();
    const cz: number = this.fps.getPositionZ();
    const yaw: number = this.fps.getYaw();
    const pitch: number = this.fps.getPitch();
    const c: ScreenPoint = this.project(wx, wy, wz, cx, cy, cz, yaw, pitch);
    const rx: number = Math.cos(yaw);
    const rz: number = -Math.sin(yaw);
    const rightPt: ScreenPoint = this.project(
      wx + rx * PAINTING_W / 2, wy, wz + rz * PAINTING_W / 2, cx, cy, cz, yaw, pitch
    );
    const topPt: ScreenPoint = this.project(
      wx, wy + PAINTING_H / 2, wz, cx, cy, cz, yaw, pitch
    );
    const hw: number = Math.abs(rightPt.x - c.x) * 2;
    const hh: number = Math.abs(c.y - topPt.y) * 2;
    const r: GhostRect = {
      x: c.x - hw / 2, y: c.y - hh / 2, w: hw > 10 ? hw : 80, h: hh > 10 ? hh : 60
    };
    return r;
  }

  private project(
    wx: number, wy: number, wz: number, cx: number, cy: number, cz: number,
    yaw: number, pitch: number
  ): ScreenPoint {
    const dx: number = wx - cx; const dy: number = wy - cy; const dz: number = wz - cz;
    const cosY: number = Math.cos(-yaw); const sinY: number = Math.sin(-yaw);
    const cosP: number = Math.cos(-pitch); const sinP: number = Math.sin(-pitch);
    const rxx: number = dx * cosY - dz * sinY;
    const rz: number = dx * sinY + dz * cosY;
    const ry: number = dy * cosP - rz * sinP;
    const rz2: number = dy * sinP + rz * cosP;
    if (rz2 <= 0.01) { const r: ScreenPoint = { x: -200, y: -200, visible: false }; return r; }
    const fovY: number = 65 * Math.PI / 180;
    const halfH: number = Math.tan(fovY / 2);
    const halfW: number = halfH * (this.screenW / Math.max(this.screenH, 1));
    const sx: number = (rxx / rz2) / halfW;
    const sy: number = -(ry / rz2) / halfH;
    const r: ScreenPoint = {
      x: (sx + 1) / 2 * this.screenW, y: (sy + 1) / 2 * this.screenH,
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

  private async placeCurrent(): Promise<void> {
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
    this.ghostVisible = false;
    this.lastHit = undefined;

    // Rebuild scene with placed artwork quads in 3D
    await this.rebuildSceneInSandbox();
  }

  private removePlacement(slotId: string): void {
    const filtered: Placement[] = [];
    for (const p of this.placements) { if (p.slotId !== slotId) filtered.push(p); }
    this.placements = filtered;
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
    this.sandboxScenePath = '';
    this.showScenePicker = false;
    this.loadScene();
  }

  private artworkImage(id: string): Resource {
    if (id === 'mona_lisa') return $rawfile('gltf/David/paintings/mona_lisa.jpg');
    if (id === 'birth_of_venus') return $rawfile('gltf/David/paintings/birth_of_venus.jpg');
    if (id === 'school_of_athens') return $rawfile('gltf/David/paintings/school_of_athens.jpg');
    if (id === 'creation_of_adam') return $rawfile('gltf/David/paintings/creation_of_adam.jpg');
    if (id === 'primavera') return $rawfile('gltf/David/paintings/botticelli_primavera.jpg');
    if (id === 'starry_night') return $rawfile('gltf/David/paintings/birth_of_venus.jpg');
    return $rawfile('gltf/David/paintings/mona_lisa.jpg');
  }

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

  // ==================== BASE64 ====================

  private base64Encode(bytes: Uint8Array): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let result = '';
    let i = 0;
    while (i < bytes.length) {
      const a = bytes[i++];
      const b = i < bytes.length ? bytes[i++] : 0;
      const c = i < bytes.length ? bytes[i++] : 0;
      const n = (a << 16) | (b << 8) | c;
      result += chars.charAt((n >> 18) & 63);
      result += chars.charAt((n >> 12) & 63);
      result += i - 2 < bytes.length ? chars.charAt((n >> 6) & 63) : '=';
      result += i - 1 < bytes.length ? chars.charAt(n & 63) : '=';
    }
    return result;
  }

  private base64Decode(b64: string): Uint8Array {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    const lookup = new Int8Array(128);
    for (let i = 0; i < chars.length; i++) { lookup[chars.charCodeAt(i)] = i; }
    b64 = b64.replace(/=+$/, '');
    const len = b64.length;
    const bytes = new Uint8Array((len * 3) / 4);
    let p = 0;
    for (let i = 0; i < len; i += 4) {
      const n = (lookup[b64.charCodeAt(i)] << 18) |
        (lookup[b64.charCodeAt(i + 1)] << 12) |
        ((i + 2 < len ? lookup[b64.charCodeAt(i + 2)] : 0) << 6) |
        (i + 3 < len ? lookup[b64.charCodeAt(i + 3)] : 0);
      bytes[p++] = (n >> 16) & 255;
      if (i + 2 < len) bytes[p++] = (n >> 8) & 255;
      if (i + 3 < len) bytes[p++] = n & 255;
    }
    return bytes.slice(0, p);
  }

  // ==================== BUILD ====================

  build() {
    Stack() {
      Column().width('100%').height('100%').backgroundColor('#0a0a1a')

      if (this.sceneReady && this.sceneInstance !== undefined) {
        Component3D({ scene: this.sceneInstance })
          .width('100%').height('100%').backgroundColor('#0a0a1a')
          .opacity(this.sceneOpacity)
          .onAreaChange((oldArea, newArea) => {
            this.screenW = newArea.width as number;
            this.screenH = newArea.height as number;
          })
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

      // CROSSHAIR
      if (this.placementMode) {
        Text('＋').fontSize(30).fontColor('#CCd4b678')
          .position({ x: '50%', y: '50%' }).markAnchor({ x: 0, y: 0 })
          .hitTestBehavior(HitTestMode.Transparent)
      }

      // GHOST
      if (this.placementMode && this.ghostVisible && this.ghostW > 0) {
        Column().width(this.ghostW).height(this.ghostH)
          .backgroundColor('#18d4b678')
          .border({ width: 2, color: this.ghostValid ? '#BBd4b678' : '#BBff4444' })
          .position({ x: this.ghostX, y: this.ghostY })
          .hitTestBehavior(HitTestMode.Transparent)
      }

      // PLACE BUTTON
      if (this.placementMode && this.ghostVisible && this.ghostValid) {
        Button('放置', { type: ButtonType.Capsule })
          .fontSize(16).height(44).padding({ left: 24, right: 24 })
          .backgroundColor('#d4b678').fontColor('#0a0a1a')
          .position({ x: '50%', y: '64%' }).markAnchor({ x: 0, y: 0 })
          .onClick(() => { this.placeCurrent(); })
      }

      // TOP-LEFT
      Row({ space: 8 }) {
        Button('←', { type: ButtonType.Capsule }).fontSize(13).height(30).width(36)
          .backgroundColor('#1a1a2e60').fontColor('#ffffff')
          .onClick(() => { router.back(); })
        Button(this.getSceneName() + ' ▾', { type: ButtonType.Capsule }).fontSize(11).height(30)
          .backgroundColor('#1a1a2e60').fontColor('#d4b678').borderColor('#d4b67844').borderWidth(1)
          .onClick(() => { this.showScenePicker = !this.showScenePicker; })
      }.position({ x: 12, y: 12 })

      // TOP-RIGHT
      Row({ space: 6 }) {
        Text(this.placements.length.toString() + '幅').fontSize(12).fontColor('#b9a57a')
        Button('导出', { type: ButtonType.Capsule }).fontSize(11).height(28)
          .backgroundColor('#1a1a2e60').fontColor('#b9a57a').borderColor('#d4b67844').borderWidth(1)
          .onClick(() => { this.exportData(); })
      }.position({ x: '100%', y: 12 }).markAnchor({ x: 105, y: 0 })

      if (this.placementMode) {
        Button('✕', { type: ButtonType.Capsule }).fontSize(12).height(30).width(36)
          .backgroundColor('#1a1a2e60').fontColor('#8a8a9a')
          .position({ x: 12, y: 50 })
          .onClick(() => { this.cancelPlacement(); })
      }

      // SCENE PICKER
      if (this.showScenePicker) {
        Column() {
          Column({ space: 6 }) {
            Text('选择场景').fontSize(15).fontColor('#f5e6c8').fontWeight(FontWeight.Medium)
            ForEach(PRESET_SCENES, (sc: SceneEntry) => {
              Row({ space: 8 }) {
                Text(sc.name).fontSize(13)
                  .fontColor(this.currentSceneId === sc.id ? '#d4b678' : '#8a8a9a')
                  .fontWeight(this.currentSceneId === sc.id ? FontWeight.Bold : FontWeight.Normal)
                Text(sc.description).fontSize(10).fontColor('#6a6a7a')
              }.width('100%').padding(10)
              .backgroundColor(this.currentSceneId === sc.id ? '#2a2a3a' : '#1a1a2e').borderRadius(8)
              .onClick(() => { this.switchScene(sc.id); })
            }, (sc: SceneEntry) => sc.id)
            Button('关闭', { type: ButtonType.Capsule }).fontSize(12).height(30)
              .backgroundColor('#1a1a2e').fontColor('#8a8a9a')
              .onClick(() => { this.showScenePicker = false; })
          }.width(260).padding(14)
          .backgroundColor('#F01a1a2e').borderColor('#88d4b678').borderWidth(1).borderRadius(12)
        }
        .width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .backgroundColor('#00000088').position({ x: 0, y: 0 })
        .onClick(() => { this.showScenePicker = false; })
      }

      // JOYSTICK
      Joystick({ onInput: (x: number, y: number) => { this.fps.setMoveInput(x, y); } })
        .position({ x: 32, y: '100%' }).markAnchor({ x: 0, y: 170 })

      // HOTBAR
      if (this.showHotbar) {
        Row({ space: 6 }) {
          Column({ space: 2 }) {
            Row() { Text('+').fontSize(16).fontColor('#d4b678') }
            .width(44).height(36).backgroundColor('#1a1a2e88').borderColor('#d4b67855')
            .borderWidth(1).borderRadius(6).borderStyle(BorderStyle.Dashed).justifyContent(FlexAlign.Center)
            Text('导入').fontSize(8).fontColor('#8a8a9a')
          }.onClick(() => { this.pickAndAddArtwork(); })

          ForEach(this.getAllArtworks(), (art: ArtworkEntry) => {
            Column({ space: 2 }) {
              Image(this.artworkImage(art.id)).width(44).height(30)
                .objectFit(ImageFit.Cover).borderRadius(4)
                .border({ width: this.selectedArtworkId === art.id ? 2 : 0, color: '#d4b678' })
              Text(art.titleZh.length > 3 ? art.titleZh.substring(0, 3) : art.titleZh)
                .fontSize(9).fontColor(this.selectedArtworkId === art.id ? '#f5e6c8' : '#8a8a9a')
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width(48)
            }.onClick(() => { this.selectArtwork(art); })
          }, (art: ArtworkEntry) => art.id)
        }
        .padding({ left: 8, right: 8, top: 6, bottom: 6 })
        .backgroundColor('#1a1a2e66').borderRadius(8)
        .position({ x: '50%', y: '100%' }).markAnchor({ x: 0, y: 60 })
      }

      // FINE-TUNE
      if (this.showFineTune) {
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
        .width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .backgroundColor('#00000044').position({ x: 0, y: 0 })
      }

      // LOADING
      if (this.loadingOpacity > 0) {
        Column({ space: 16 }) {
          LoadingProgress().width(48).height(48).color('#d4b678')
          Text('加载展厅...').fontSize(15).fontColor('#d4b67899').letterSpacing(2)
        }
        .width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .linearGradient({ angle: 135, colors: [['#0a0a1a', 0], ['#1a1a2e', 0.5], ['#0f0f1f', 1]] })
        .opacity(this.loadingOpacity)
      }
    }.width('100%').height('100%')
  }
}
