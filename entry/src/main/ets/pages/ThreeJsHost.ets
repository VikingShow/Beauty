import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0104;

@Entry
@Component
struct ThreeJsHost {
  private webController: webview.WebviewController = new webview.WebviewController();

  build() {
    Stack() {
      Column().width('100%').height('100%').backgroundColor('#0a0a1a')

      Web({ src: $rawfile('web/index.html'), controller: this.webController })
        .width('100%').height('100%')
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .onInterceptRequest((event: ESObject) => {
          const url: string = event['request']?.['getRequestUrl']?.() as string ?? '';
          if (!url.startsWith('rawfile://')) { return null; }

          const rawPath: string = url.substring('rawfile://'.length);
          hilog.info(DOMAIN, 'ThreeJsHost', 'Intercept: %{public}s', rawPath);

          try {
            const ctx = getContext(this);
            const data: Uint8Array = ctx.resourceManager.getRawFileContentSync(rawPath);

            let mime: string = 'application/octet-stream';
            if (rawPath.endsWith('.gltf')) { mime = 'model/gltf+json'; }
            else if (rawPath.endsWith('.png')) { mime = 'image/png'; }
            else if (rawPath.endsWith('.jpg') || rawPath.endsWith('.jpeg')) { mime = 'image/jpeg'; }

            const resp: ESObject = {
              'responseData': data.buffer,
              'responseMimeType': mime
            };
            return resp;
          } catch (e) {
            hilog.error(DOMAIN, 'ThreeJsHost', 'Fail: %{public}s', rawPath);
            return null;
          }
        })
        .onPageEnd(() => {
          hilog.info(DOMAIN, 'ThreeJsHost', 'Page loaded');
        })
    }
    .width('100%').height('100%')
  }
}
