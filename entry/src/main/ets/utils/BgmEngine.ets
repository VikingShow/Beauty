import { media } from '@kit.MediaKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0104;

/**
 * 背景音乐引擎 - 基于 AVPlayer 循环播放文艺复兴古典乐。
 *
 * 使用方式：
 *   const bgm = BgmEngine.getInstance();
 *   bgm.init(getContext());
 *   bgm.play();
 *   bgm.toggleMute();  // 开关
 */
export class BgmEngine {
  private static instance: BgmEngine | undefined = undefined;
  private player: media.AVPlayer | undefined = undefined;
  private ready: boolean = false;
  muted: boolean = false;

  static getInstance(): BgmEngine {
    if (BgmEngine.instance === undefined) {
      BgmEngine.instance = new BgmEngine();
    }
    return BgmEngine.instance!;
  }

  async init(context: Context): Promise<void> {
    if (this.ready) return;
    try {
      this.player = await media.createAVPlayer();
      // 从 rawfile 加载文艺复兴音乐文件
      const fd = context.resourceManager.getRawFdSync('bgm_renaissance.mp3');
      this.player.fdSrc = fd as media.AVFileDescriptor;
      this.player.loop = true;
      this.player.setVolume(0.25);

      this.ready = true;
      hilog.info(DOMAIN, 'BGM', 'player ready');
    } catch (e) {
      hilog.warn(DOMAIN, 'BGM', 'init failed (bgm_renaissance.mp3 not found?): %{public}s', JSON.stringify(e));
      this.ready = false;
    }
  }

  play(): void {
    if (!this.ready || this.player === undefined || this.muted) return;
    try {
      this.player.play();
    } catch (_e) {
      // ignore
    }
  }

  pause(): void {
    if (this.player !== undefined) {
      try {
        this.player.pause();
      } catch (_e) {
        // ignore
      }
    }
  }

  toggleMute(): void {
    this.muted = !this.muted;
    if (this.muted) {
      this.pause();
    } else {
      this.play();
    }
  }

  destroy(): void {
    if (this.player !== undefined) {
      try {
        this.player.release();
      } catch (_e) {
        // ignore
      }
      this.player = undefined;
    }
    this.ready = false;
  }
}
