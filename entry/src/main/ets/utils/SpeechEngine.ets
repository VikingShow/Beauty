import { textToSpeech } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0103;

/**
 * AI 语音旁白引擎 - 封装鸿蒙 Core Speech Kit TTS。
 */
export class SpeechEngine {
  private static instance: SpeechEngine | undefined = undefined;
  private engine: textToSpeech.TextToSpeechEngine | undefined = undefined;
  private ready: boolean = false;
  private queue: string[] = [];
  private speaking: boolean = false;
  private lastText: string = '';
  private generation: number = 0;
  muted: boolean = false;
  currentSubtitle: string = '';
  private subtitleCallback: ((text: string) => void) | undefined = undefined;

  static getInstance(): SpeechEngine {
    if (SpeechEngine.instance === undefined) {
      SpeechEngine.instance = new SpeechEngine();
    }
    return SpeechEngine.instance!;
  }

  init(): void {
    if (this.ready) return;
    try {
      textToSpeech.createEngine(
        { language: 'zh-CN', person: 0, online: 1 },
        (err: BusinessError, engine: textToSpeech.TextToSpeechEngine): void => {
          if (err) {
            hilog.warn(DOMAIN, 'Speech', 'TTS init error: %{public}s', err.message);
            return;
          }
          this.engine = engine;

          engine.setListener({
            onStart: (): void => {
              hilog.info(DOMAIN, 'Speech', 'started');
            },
            onComplete: (): void => {
              const gen: number = this.generation;
              this.speaking = false;
              this.setSubtitle('');
              this.flushQueue(gen);
            },
            onError: (_rid: string, _ec: number, msg: string): void => {
              hilog.error(DOMAIN, 'Speech', 'error: %{public}s', msg);
              this.speaking = false;
              this.setSubtitle('');
              this.flushQueue(this.generation);
            },
            onStop: (): void => {
              // onStop 可能是旧 utterance 被新 utterance 打断触发的异步回调，
              // 不清字幕——让新 utterance 的 doSpeak 来设。
              this.speaking = false;
            },
          });
          this.ready = true;
          hilog.info(DOMAIN, 'Speech', 'ready');
        }
      );
    } catch (e) {
      hilog.warn(DOMAIN, 'Speech', 'init failed: %{public}s', JSON.stringify(e));
      this.ready = false;
    }
  }

  onSubtitleChange(cb: (text: string) => void): void {
    this.subtitleCallback = cb;
  }

  toggleMute(): void {
    this.muted = !this.muted;
    if (this.muted) {
      this.stop();
      this.setSubtitle('');
    }
  }

  speak(text: string): void {
    if (!text || !this.ready || this.engine === undefined) return;
    if (text === this.lastText) return;
    this.lastText = text;

    if (this.speaking) {
      if (this.queue.length > 0) this.queue[this.queue.length - 1] = text;
      else this.queue.push(text);
      return;
    }

    this.doSpeak(text);
  }

  speakNow(text: string): void {
    if (!text || !this.ready || this.engine === undefined) return;
    this.stop();
    this.doSpeak(text);
  }

  stop(): void {
    // 递增 generation，让任何飞行中的回调作废
    this.generation++;
    if (this.engine !== undefined) {
      try { this.engine.stop(); } catch (_e) { /* ignore */ }
    }
    this.speaking = false;
    this.queue = [];
  }

  destroy(): void {
    this.stop();
    if (this.engine !== undefined) {
      try { this.engine.shutdown(); } catch (_e) { /* ignore */ }
      this.engine = undefined;
    }
    this.ready = false;
  }

  private setSubtitle(text: string): void {
    this.currentSubtitle = text;
    if (this.subtitleCallback !== undefined) {
      this.subtitleCallback(text);
    }
  }

  private doSpeak(text: string): void {
    if (this.engine === undefined) return;
    if (this.muted) {
      this.setSubtitle(text);
      return;
    }
    this.generation++;
    const gen: number = this.generation;
    this.speaking = true;
    this.setSubtitle(text);
    const requestId: string = gen.toString();
    try {
      this.engine.speak(text, { requestId: requestId });
    } catch (e) {
      hilog.error(DOMAIN, 'Speech', 'speak failed: %{public}s', JSON.stringify(e));
      this.speaking = false;
      this.setSubtitle('');
    }
  }

  private flushQueue(gen: number): void {
    // 如果已经有新 utterance 启动了，不  flush
    if (gen !== this.generation) return;
    if (this.queue.length > 0) {
      const next: string | undefined = this.queue.pop();
      this.queue = [];
      if (next !== undefined) this.doSpeak(next);
    }
  }
}
