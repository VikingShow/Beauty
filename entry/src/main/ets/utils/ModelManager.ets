import { picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { RenderContext } from '@kit.ArkGraphics3D';

const DOMAIN = 0x0105;
const TAG = 'ModelManager';
const USER_MODELS_DIR = 'user_models';
const USER_ARTWORKS_DIR = 'user_artworks';
const USER_GS_DIR = 'user_gs';

const VALID_MODEL_EXTS: string[] = ['.glb', '.gltf'];
const VALID_GS_EXTS: string[] = ['.ply', '.mp4'];

export class ModelManager {
  private context: Context | undefined = undefined;
  private sandboxProtocol: string = 'sandbox';

  init(context: Context): void {
    this.context = context;
    this.ensureDirs();
  }

  private ensureDir(subDir: string): void {
    if (this.context === undefined) return;
    const dir: string = `${this.context.filesDir}/${subDir}`;
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir);
      hilog.info(DOMAIN, TAG, 'created dir: %{public}s', dir);
    }
  }

  private ensureDirs(): void {
    this.ensureDir(USER_MODELS_DIR);
    this.ensureDir(USER_ARTWORKS_DIR);
    this.ensureDir(USER_GS_DIR);
  }

  async pickModelFile(): Promise<string> {
    return this.pickAndCopy(USER_MODELS_DIR, VALID_MODEL_EXTS);
  }

  async pickArtworkFile(): Promise<string> {
    return this.pickAndCopy(USER_ARTWORKS_DIR, VALID_MODEL_EXTS);
  }

  async pickGSFile(): Promise<string> {
    return this.pickAndCopy(USER_GS_DIR, VALID_GS_EXTS);
  }

  private async pickAndCopy(subDir: string, validExts: string[]): Promise<string> {
    if (this.context === undefined) {
      throw new Error('ModelManager not initialized');
    }
    const docPicker = new picker.DocumentViewPicker();
    const uris: Array<string> = await docPicker.select({ maxSelectNumber: 1 });
    if (uris.length === 0) {
      throw new Error('No file selected');
    }
    const srcUri: string = uris[0];
    const rawName: string = decodeURIComponent(srcUri.split('/').pop() ?? 'unknown');
    const ext: string = rawName.substring(rawName.lastIndexOf('.')).toLowerCase();
    if (!validExts.includes(ext)) {
      throw new Error(`Invalid file type: ${ext}. Expected: ${validExts.join(', ')}`);
    }
    const destDir: string = `${this.context.filesDir}/${subDir}`;
    const destPath: string = `${destDir}/${rawName}`;
    if (fs.accessSync(destPath)) {
      hilog.info(DOMAIN, TAG, 'file exists, overwriting: %{public}s', rawName);
      fs.unlinkSync(destPath);
    }
    await fs.copyFile(srcUri, destPath);
    hilog.info(DOMAIN, TAG, 'copied to: %{public}s', destPath);
    return destPath;
  }

  registerSandboxProtocol(renderContext: RenderContext): void {
    if (this.context === undefined) return;
    const filesDir: string = this.context.filesDir;
    const result: boolean = renderContext.registerResourcePath(this.sandboxProtocol, filesDir);
    hilog.info(DOMAIN, TAG, 'registerResourcePath result: %{public}s', result.toString());
  }

  getSandboxUri(relativePath: string): string {
    return `${this.sandboxProtocol}:///${relativePath}`;
  }

  getAbsolutePath(subDir: string, fileName: string): string {
    if (this.context === undefined) return '';
    return `${this.context.filesDir}/${subDir}/${fileName}`;
  }

  listFiles(subDir: string): string[] {
    if (this.context === undefined) return [];
    const dir: string = `${this.context.filesDir}/${subDir}`;
    if (!fs.accessSync(dir)) return [];
    const entries: string[] = [];
    const list = fs.listFileSync(dir);
    for (const name of list) {
      entries.push(`${dir}/${name}`);
    }
    return entries;
  }

  deleteFile(path: string): void {
    if (fs.accessSync(path)) {
      fs.unlinkSync(path);
      hilog.info(DOMAIN, TAG, 'deleted: %{public}s', path);
    }
  }

  getFileSize(path: string): number {
    if (!fs.accessSync(path)) return 0;
    const stat = fs.statSync(path);
    return stat.size;
  }
}
