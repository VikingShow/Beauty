import { router } from '@kit.ArkUI';
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
        .onPageEnd(() => {
          hilog.info(DOMAIN, 'ThreeJsHost', 'Web page loaded');
        })
        .onErrorReceive((err) => {
          hilog.error(DOMAIN, 'ThreeJsHost', 'Web error: %{public}s', JSON.stringify(err));
        })
    }
    .width('100%').height('100%')
  }
}
