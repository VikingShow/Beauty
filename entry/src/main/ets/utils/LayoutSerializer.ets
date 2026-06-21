import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ExhibitionLayout, PlacedArtwork, Position3, Scale3, Quaternion, generateId } from './GalleryTypes';

const DOMAIN = 0x0105;
const TAG = 'LayoutSerializer';
const PREFS_NAME = 'artree_exhibitions';
const KEY_LAYOUTS = 'exhibition_layouts';

export class LayoutSerializer {
  async save(context: Context, layout: ExhibitionLayout): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFS_NAME);
    const existing = await this.loadAll(context);
    const idx = existing.findIndex((l: ExhibitionLayout) => l.id === layout.id);
    layout.updatedAt = Date.now();
    if (idx >= 0) {
      existing[idx] = layout;
    } else {
      existing.push(layout);
    }
    await prefs.put(KEY_LAYOUTS, JSON.stringify(existing));
    await prefs.flush();
    hilog.info(DOMAIN, TAG, 'saved layout: %{public}s', layout.id);
  }

  async loadAll(context: Context): Promise<ExhibitionLayout[]> {
    try {
      const prefs = await preferences.getPreferences(context, PREFS_NAME);
      const raw = await prefs.get(KEY_LAYOUTS, '[]') as string;
      const parsed: object[] = JSON.parse(raw) as object[];
      return parsed.map((o: object) => this.deserializeLayout(o));
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'loadAll failed: %{public}s', JSON.stringify(e));
      return [];
    }
  }

  async loadById(context: Context, id: string): Promise<ExhibitionLayout | null> {
    const all = await this.loadAll(context);
    const found = all.find((l: ExhibitionLayout) => l.id === id);
    return found !== undefined ? found : null;
  }

  async deleteById(context: Context, id: string): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFS_NAME);
    const existing = await this.loadAll(context);
    const filtered = existing.filter((l: ExhibitionLayout) => l.id !== id);
    await prefs.put(KEY_LAYOUTS, JSON.stringify(filtered));
    await prefs.flush();
    hilog.info(DOMAIN, TAG, 'deleted layout: %{public}s', id);
  }

  async exportToFile(context: Context, layout: ExhibitionLayout): Promise<string> {
    const json = JSON.stringify(layout, null, 2);
    const fileName = `exhibition_${layout.id}.json`;
    const dir = `${context.filesDir}/exports`;
    if (!context) return '';
    const fs = await import('@kit.CoreFileKit');
    if (!fs.fileIo.accessSync(dir)) {
      fs.fileIo.mkdirSync(dir);
    }
    const filePath = `${dir}/${fileName}`;
    const fd = fs.fileIo.openSync(filePath, 0o102 | 0o2);
    fs.fileIo.writeSync(fd.fd, json);
    fs.fileIo.closeSync(fd);
    hilog.info(DOMAIN, TAG, 'exported to: %{public}s', filePath);
    return filePath;
  }

  createEmpty(name: string, sceneUri: string, sceneType: 'gltf' | '3dgs'): ExhibitionLayout {
    return {
      id: generateId(),
      name: name,
      sceneUri: sceneUri,
      sceneType: sceneType,
      placedArtworks: [],
      cameraPosition: { x: 0, y: 1.65, z: 3 },
      cameraRotation: { x: 0, y: 0, z: 0, w: 1 },
      createdAt: Date.now(),
      updatedAt: Date.now()
    };
  }

  private deserializeLayout(o: object): ExhibitionLayout {
    const src = o as Record<string, Object>;
    return {
      id: (src['id'] ?? '') as string,
      name: (src['name'] ?? '') as string,
      sceneUri: (src['sceneUri'] ?? '') as string,
      sceneType: (src['sceneType'] ?? 'gltf') as 'gltf' | '3dgs',
      placedArtworks: this.deserializeArtworks(src['placedArtworks']),
      cameraPosition: this.deserializePos(src['cameraPosition']),
      cameraRotation: this.deserializeQuat(src['cameraRotation']),
      createdAt: (src['createdAt'] ?? 0) as number,
      updatedAt: (src['updatedAt'] ?? 0) as number
    };
  }

  private deserializeArtworks(raw: Object | undefined): PlacedArtwork[] {
    if (raw === undefined || raw === null) return [];
    const arr = raw as Object[];
    return arr.map((o: Object) => {
      const src = o as Record<string, Object>;
      return {
        id: (src['id'] ?? '') as string,
        modelUri: (src['modelUri'] ?? '') as string,
        modelName: (src['modelName'] ?? '') as string,
        position: this.deserializePos(src['position']),
        rotation: this.deserializeQuat(src['rotation']),
        scale: this.deserializeScale(src['scale']),
        nodePath: (src['nodePath'] ?? '') as string,
        slotId: (src['slotId'] ?? '') as string
      };
    });
  }

  private deserializePos(raw: Object | undefined): Position3 {
    if (raw === undefined || raw === null) return { x: 0, y: 0, z: 0 };
    const src = raw as Record<string, number>;
    return { x: src['x'] ?? 0, y: src['y'] ?? 0, z: src['z'] ?? 0 };
  }

  private deserializeQuat(raw: Object | undefined): Quaternion {
    if (raw === undefined || raw === null) return { x: 0, y: 0, z: 0, w: 1 };
    const src = raw as Record<string, number>;
    return { x: src['x'] ?? 0, y: src['y'] ?? 0, z: src['z'] ?? 0, w: src['w'] ?? 1 };
  }

  private deserializeScale(raw: Object | undefined): Scale3 {
    if (raw === undefined || raw === null) return { x: 1, y: 1, z: 1 };
    const src = raw as Record<string, number>;
    return { x: src['x'] ?? 1, y: src['y'] ?? 1, z: src['z'] ?? 1 };
  }
}
