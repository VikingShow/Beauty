import {
  Scene,
  SceneResourceFactory,
  Camera,
  Light,
  LightType,
  SceneNodeParameters,
  Node,
  RenderContext,
  RaycastParameters,
  RaycastResult
} from '@kit.ArkGraphics3D';
import { spatialRender } from '@kit.SpatialReconKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ModelManager } from './ModelManager';
import { PlacedArtwork, Position3, Scale3, Quaternion, generateId } from './GalleryTypes';

const DOMAIN = 0x0105;
const TAG = 'GalleryEditor';

export type EditorMode = 'navigate' | 'place' | 'select' | 'transform';

export class GalleryEditor {
  private scene: Scene | undefined = undefined;
  private camera: Camera | undefined = undefined;
  private factory: SceneResourceFactory | undefined = undefined;
  private modelManager: ModelManager = new ModelManager();
  private artworksRoot: Node | undefined = undefined;
  private placedArtworks: PlacedArtwork[] = [];
  private selectedArtwork: PlacedArtwork | null = null;
  private selectedNode: Node | null = null;
  private mode: EditorMode = 'navigate';
  private ghostNode: Node | undefined = undefined;
  private pendingArtworkPath: string = '';
  private onUpdate: (() => void) | undefined = undefined;
  private renderContext: RenderContext | undefined = undefined;

  init(context: Context): void {
    this.modelManager.init(context);
  }

  setOnUpdate(cb: () => void): void {
    this.onUpdate = cb;
  }

  getMode(): EditorMode {
    return this.mode;
  }

  setMode(m: EditorMode): void {
    this.mode = m;
    this.notifyUpdate();
  }

  getPlacedArtworks(): PlacedArtwork[] {
    return this.placedArtworks;
  }

  getSelectedArtwork(): PlacedArtwork | null {
    return this.selectedArtwork;
  }

  getScene(): Scene | undefined {
    return this.scene;
  }

  getCamera(): Camera | undefined {
    return this.camera;
  }

  private notifyUpdate(): void {
    if (this.onUpdate !== undefined) {
      this.onUpdate();
    }
  }

  async loadScene(uri: Resource | string): Promise<void> {
    try {
      hilog.info(DOMAIN, TAG, 'loading scene...');
      this.scene = await Scene.load(uri);
      this.factory = this.scene.getResourceFactory();

      const rc: RenderContext | null = Scene.getDefaultRenderContext();
      if (rc !== null) {
        this.renderContext = rc;
        this.modelManager.registerSandboxProtocol(rc);
      }

      const root: Node | null = this.scene.root;
      if (root !== null) {
        const artworksParams: SceneNodeParameters = { name: 'artworks_root' };
        this.artworksRoot = await this.factory.createNode(artworksParams);
        root.children.append(this.artworksRoot);
        hilog.info(DOMAIN, TAG, 'artworks root node created');
      }

      const camParams: SceneNodeParameters = { name: 'editorCamera' };
      this.camera = await this.factory.createCamera(camParams);
      this.camera.enabled = true;
      this.camera.fov = 70 * Math.PI / 180;
      this.camera.nearPlane = 0.1;
      this.camera.farPlane = 100.0;
      this.camera.clearColor = { r: 0.72, g: 0.78, b: 0.85, a: 1.0 };

      const warmWhite: RGBA = { r: 1.0, g: 0.96, b: 0.88, a: 1.0 };
      const coolFill: RGBA = { r: 0.7, g: 0.8, b: 0.95, a: 1.0 };

      const keyParams: SceneNodeParameters = { name: 'editorKey' };
      const keyLight: Light = await this.factory.createLight(keyParams, LightType.DIRECTIONAL);
      keyLight.enabled = true;
      keyLight.color = warmWhite;
      keyLight.intensity = 14.0;
      keyLight.rotation = { x: -0.6088, y: 0, z: 0, w: 0.7934 };

      const fillParams: SceneNodeParameters = { name: 'editorFill' };
      const fillLight: Light = await this.factory.createLight(fillParams, LightType.DIRECTIONAL);
      fillLight.enabled = true;
      fillLight.color = coolFill;
      fillLight.intensity = 6.0;
      fillLight.rotation = { x: 0, y: 1, z: 0, w: 0 };

      hilog.info(DOMAIN, TAG, 'scene loaded OK');
      this.notifyUpdate();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'loadScene failed: %{public}s', JSON.stringify(e));
      throw new Error('loadScene failed');
    }
  }

  async importArtwork(uri: string): Promise<PlacedArtwork> {
    if (this.scene === undefined || this.factory === undefined || this.artworksRoot === undefined) {
      throw new Error('Scene not loaded');
    }
    try {
      hilog.info(DOMAIN, TAG, 'importing artwork: %{public}s', uri);
      const artworkScene: Scene = await Scene.load(uri);
      const name: string = 'artwork_' + generateId();
      const importedNode: Node = this.scene.importScene(name, artworkScene, this.artworksRoot);

      const startPos: Position3 = { x: 0, y: 0, z: 0 };
      if (this.camera !== undefined) {
        startPos.x = this.camera.position.x - Math.sin(2 * Math.atan2(this.camera.rotation.y, this.camera.rotation.w)) * 2;
        startPos.y = this.camera.position.y;
        startPos.z = this.camera.position.z - Math.cos(2 * Math.atan2(this.camera.rotation.y, this.camera.rotation.w)) * 2;
      }
      importedNode.position = startPos;

      const fileName: string = uri.split('/').pop() ?? 'artwork';
      const artwork: PlacedArtwork = {
        id: generateId(),
        modelUri: uri,
        modelName: fileName.replace(/\.(glb|gltf)$/i, ''),
        position: startPos,
        rotation: { x: 0, y: 0, z: 0, w: 1 },
        scale: { x: 1, y: 1, z: 1 },
        nodePath: name,
        slotId: ''
      };
      this.placedArtworks = this.placedArtworks.concat([artwork]);
      artworkScene.destroy();
      this.mode = 'place';
      this.selectedArtwork = artwork;
      this.selectedNode = importedNode;
      hilog.info(DOMAIN, TAG, 'artwork imported: %{public}s', artwork.id);
      this.notifyUpdate();
      return artwork;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'importArtwork failed: %{public}s', JSON.stringify(e));
      throw new Error('importArtwork failed');
    }
  }

  selectArtworkById(id: string): void {
    const found = this.placedArtworks.find((a: PlacedArtwork) => a.id === id);
    if (found !== undefined) {
      this.selectedArtwork = found;
      this.mode = 'select';
      if (this.scene !== undefined && this.artworksRoot !== undefined) {
        const node: Node | null = this.scene.getNodeByPath(found.nodePath);
        if (node !== null) {
          this.selectedNode = node;
        }
      }
      this.notifyUpdate();
    }
  }

  deselectArtwork(): void {
    this.selectedArtwork = null;
    this.selectedNode = null;
    this.mode = 'navigate';
    this.notifyUpdate();
  }

  removeSelectedArtwork(): void {
    if (this.selectedNode !== null && this.selectedNode.parent !== null) {
      this.selectedNode.parent.children.remove(this.selectedNode);
    }
    if (this.selectedArtwork !== null) {
      const selId: string = this.selectedArtwork.id;
      this.placedArtworks = this.placedArtworks.filter((a: PlacedArtwork) => a.id !== selId);
    }
    this.selectedArtwork = null;
    this.selectedNode = null;
    this.mode = 'navigate';
    hilog.info(DOMAIN, TAG, 'artwork removed');
    this.notifyUpdate();
  }

  setArtworkPosition(pos: Position3): void {
    if (this.selectedNode !== null) {
      this.selectedNode.position = pos;
    }
    if (this.selectedArtwork !== null) {
      this.selectedArtwork.position = pos;
    }
    this.notifyUpdate();
  }

  setArtworkRotation(rot: Quaternion): void {
    if (this.selectedNode !== null) {
      this.selectedNode.rotation = rot;
    }
    if (this.selectedArtwork !== null) {
      this.selectedArtwork.rotation = rot;
    }
    this.notifyUpdate();
  }

  setArtworkScale(s: Scale3): void {
    if (this.selectedNode !== null) {
      this.selectedNode.scale = s;
    }
    if (this.selectedArtwork !== null) {
      this.selectedArtwork.scale = s;
    }
    this.notifyUpdate();
  }

  rotateSelectedY(deltaDeg: number): void {
    if (this.selectedArtwork === null || this.selectedNode === null) return;
    const deltaRad: number = deltaDeg * Math.PI / 180;
    const curY: number = this.selectedArtwork.rotation.y;
    const curW: number = this.selectedArtwork.rotation.w;
    const halfDelta: number = deltaRad / 2;
    const sinH: number = Math.sin(halfDelta);
    const cosH: number = Math.cos(halfDelta);
    const newRot: Quaternion = {
      x: this.selectedArtwork.rotation.x,
      y: curW * sinH + curY * cosH,
      z: this.selectedArtwork.rotation.z,
      w: curW * cosH - curY * sinH
    };
    this.setArtworkRotation(newRot);
  }

  scaleSelected(factor: number): void {
    if (this.selectedArtwork === null) return;
    const s: Scale3 = {
      x: this.selectedArtwork.scale.x * factor,
      y: this.selectedArtwork.scale.y * factor,
      z: this.selectedArtwork.scale.z * factor
    };
    this.setArtworkScale(s);
  }

  nudgeSelected(dx: number, dy: number, dz: number): void {
    if (this.selectedArtwork === null) return;
    const p: Position3 = {
      x: this.selectedArtwork.position.x + dx,
      y: this.selectedArtwork.position.y + dy,
      z: this.selectedArtwork.position.z + dz
    };
    this.setArtworkPosition(p);
  }

  async raycast(screenX: number, screenY: number, viewWidth: number, viewHeight: number): Promise<Node | null> {
    if (this.camera === undefined) return null;
    const ndcX: number = (screenX / viewWidth) * 2 - 1;
    const ndcY: number = 1 - (screenY / viewHeight) * 2;
    try {
      const params: RaycastParameters = {};
      if (this.artworksRoot !== undefined) {
        params.rootNode = this.artworksRoot;
      }
      const results: RaycastResult[] = await this.camera.raycast(
        { x: ndcX, y: ndcY },
        params
      );
      if (results.length > 0) {
        return results[0].node;
      }
      return null;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'raycast failed: %{public}s', JSON.stringify(e));
      return null;
    }
  }

  async raycastHitPosition(screenX: number, screenY: number, viewWidth: number, viewHeight: number): Promise<Position3 | null> {
    if (this.camera === undefined) return null;
    const ndcX: number = (screenX / viewWidth) * 2 - 1;
    const ndcY: number = 1 - (screenY / viewHeight) * 2;
    try {
      const results: RaycastResult[] = await this.camera.raycast({ x: ndcX, y: ndcY }, {});
      if (results.length > 0) {
        return results[0].hitPosition;
      }
      return null;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'raycastHitPosition failed: %{public}s', JSON.stringify(e));
      return null;
    }
  }

  moveSelectedToPosition(pos: Position3): void {
    if (this.selectedNode !== null && this.selectedArtwork !== null) {
      this.selectedNode.position = pos;
      this.selectedArtwork.position = pos;
      this.notifyUpdate();
    }
  }

  async load3DGSScene(gsUri: string): Promise<void> {
    if (this.scene === undefined || this.factory === undefined) {
      throw new Error('Scene not loaded');
    }
    try {
      if (this.renderContext !== undefined) {
        this.renderContext.loadPlugin(spatialRender.GSPlugin.PLUGIN_ID);
      }
      hilog.info(DOMAIN, TAG, '3DGS plugin loaded, creating GSNode');
      const gsNode: spatialRender.GSNode = await this.factory.createNode({ name: 'gs_scene', path: '//gs_scene' });
      if (this.artworksRoot !== undefined) {
        this.artworksRoot.children.append(gsNode);
      }
      const importSettings: spatialRender.GSImportSettings = { uri: gsUri };
      await spatialRender.GSPlugin.loadGSNode(this.scene, importSettings, gsNode);
      gsNode.position = { x: 0, y: 0, z: 0 };
      hilog.info(DOMAIN, TAG, '3DGS node loaded OK');
      this.notifyUpdate();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'load3DGSScene failed: %{public}s', JSON.stringify(e));
      throw new Error('3DGS load failed');
    }
  }

  destroy(): void {
    if (this.scene !== undefined) {
      this.scene.destroy();
      this.scene = undefined;
    }
  }
}

interface RGBA {
  r: number;
  g: number;
  b: number;
  a: number;
}
