import { preferences } from '@kit.ArkData';
import { fileIo as fs } from '@kit.CoreFileKit';
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
      const raw = await prefs.get(KEY_LAYOUTS, '[]');
      const parsed: ExhibitionLayout[] = JSON.parse(raw.toString());
      return parsed;
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
    const fileName = 'exhibition_' + layout.id + '.json';
    const dir = context.filesDir + '/exports';
    if (!context) return '';
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir);
    }
    const filePath = dir + '/' + fileName;
    const fd = fs.openSync(filePath, 0o102 | 0o2);
    fs.writeSync(fd.fd, json);
    fs.closeSync(fd);
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
}
