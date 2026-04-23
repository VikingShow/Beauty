import { DAVID_EXHIBITS, Exhibit } from '../scenes/Exhibits';
import {
  Clue,
  DAVID_CLUES,
  TOTAL_CLUE_COUNT,
  isCollected,
  isCandidate,
  candidateExhibitIds,
} from '../scenes/Clues';

/**
 * 侦探笔记模态：点击右侧"线索"计数器触发。
 *
 * 两栏：
 *   · 线索区：6 条窃语（已集带字号金色 + 叙述；未集显灰"走近某画可听见"）
 *   · 推理区：18 幅画作列表，根据 excludes 自动标记"候选 / 已排除"
 *
 * 3B 只提供信息查看与筛选，不触发指认——指认交给 3C（走到目标画前）。
 */
@Component
export struct NotebookModal {
  @Prop @Watch('onVisibleChange') visible: boolean = false;
  @Prop discoveredClueIds: Array<string> = [];
  onClose: () => void = () => {};

  @State private backdropOpacity: number = 0;
  @State private contentOpacity: number = 0;
  @State private contentOffsetY: number = 20;

  onVisibleChange(): void {
    if (this.visible) {
      animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
        this.backdropOpacity = 1;
      });
      setTimeout(() => {
        animateTo({ duration: 320, curve: Curve.EaseOut }, () => {
          this.contentOpacity = 1;
          this.contentOffsetY = 0;
        });
      }, 40);
    } else {
      this.backdropOpacity = 0;
      this.contentOpacity = 0;
      this.contentOffsetY = 20;
    }
  }

  build() {
    if (this.visible) {
      Stack() {
        // 背景蒙层
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#E8000000')
          .opacity(this.backdropOpacity)
          .onClick(() => {
            this.onClose();
          })

        // 笔记本卡片
        Column() {
          this.buildHeader()
          Scroll() {
            Column({ space: 20 }) {
              this.buildClueSection()
              this.buildCandidateSection()
            }
            .padding({ left: 24, right: 24, top: 16, bottom: 24 })
            .alignItems(HorizontalAlign.Start)
            .width('100%')
          }
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
          .width('100%')
        }
        .width('88%')
        .height('86%')
        .constraintSize({ maxWidth: 760 })
        .backgroundColor('#F20a0a1a')
        .borderColor('#88d4b678')
        .borderWidth(1)
        .borderRadius(14)
        .opacity(this.contentOpacity)
        .translate({ y: this.contentOffsetY })
      }
      .width('100%')
      .height('100%')
      .alignContent(Alignment.Center)
      .hitTestBehavior(HitTestMode.Default)
    }
  }

  @Builder
  buildHeader() {
    Column() {
      Row() {
        Column({ space: 2 }) {
          Text('侦探笔记')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f5e6c8')
            .letterSpacing(4)
          Text('根特悬案 · 公正法官藏身处')
            .fontSize(11)
            .fontColor('#8a8a9a')
            .letterSpacing(2)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // 关闭按钮
        Row() {
          Image($r('app.media.icon_close'))
            .width(18)
            .height(18)
            .fillColor('#d4b678')
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .borderRadius(20)
        .onClick(() => {
          this.onClose();
        })
      }
      .width('100%')
      .padding({ left: 24, right: 12, top: 18, bottom: 14 })

      Divider()
        .strokeWidth(1)
        .color('#55d4b678')
    }
    .width('100%')
  }

  @Builder
  buildClueSection() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Image($r('app.media.icon_book'))
          .width(16)
          .height(16)
          .fillColor('#d4b678')
        Text('线索')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#d4b678')
          .letterSpacing(4)
        Text(`${this.discoveredClueIds.length} / ${TOTAL_CLUE_COUNT}`)
          .fontSize(12)
          .fontColor('#b9a57a')
          .letterSpacing(1)
      }

      ForEach(DAVID_CLUES, (clue: Clue) => {
        this.buildClueRow(clue, isCollected(clue.id, this.discoveredClueIds))
      }, (clue: Clue) => clue.id)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  buildClueRow(clue: Clue, collected: boolean) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        if (collected) {
          Image($r('app.media.icon_flame'))
            .width(14)
            .height(14)
            .fillColor('#b9a57a')
        } else {
          Image($r('app.media.icon_search'))
            .width(13)
            .height(13)
            .fillColor('#55d4b678')
        }
        Text(clue.orderLabel)
          .fontSize(13)
          .fontColor(collected ? '#b9a57a' : '#6a6a7a')
          .letterSpacing(3)
          .layoutWeight(1)

        Text(collected ? '已收入' : '待发现')
          .fontSize(11)
          .fontColor(collected ? '#0a0a1a' : '#8a8a9a')
          .backgroundColor(collected ? '#d4b678' : '#33d4b678')
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(9)
      }
      .width('100%')

      if (collected) {
        Text('「 ' + clue.whisper + ' 」')
          .fontSize(14)
          .fontColor('#f5e6c8')
          .fontStyle(FontStyle.Italic)
          .lineHeight(22)

        Text('→ 筛选条件：' + clue.criterion)
          .fontSize(12)
          .fontColor('#9e9e80')
          .letterSpacing(1)
      } else {
        Text('走近某幅画作方能听见')
          .fontSize(13)
          .fontColor('#6a6a7a')
          .fontStyle(FontStyle.Italic)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(collected ? '#F012122a' : '#99121220')
    .borderColor(collected ? '#55d4b678' : '#22d4b678')
    .borderWidth(1)
    .borderRadius(8)
  }

  @Builder
  buildCandidateSection() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Image($r('app.media.icon_search'))
          .width(16)
          .height(16)
          .fillColor('#d4b678')
        Text('推理 · 藏身处候选')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#d4b678')
          .letterSpacing(4)
        Text(this.candidateCountLabel())
          .fontSize(12)
          .fontColor('#b9a57a')
          .letterSpacing(1)
      }

      if (this.discoveredClueIds.length === 0) {
        Text('尚未收集任何线索。所有 18 幅画作皆有可能。')
          .fontSize(12)
          .fontColor('#8a8a9a')
          .margin({ bottom: 4 })
      }

      ForEach(DAVID_EXHIBITS, (e: Exhibit) => {
        this.buildCandidateRow(e, isCandidate(e.id, this.discoveredClueIds))
      }, (e: Exhibit) => e.id)

      // 结语
      Column({ space: 4 }) {
        Divider()
          .strokeWidth(1)
          .color('#33d4b678')
          .margin({ top: 8, bottom: 8 })
        Text(this.footerHint())
          .fontSize(12)
          .fontColor('#9e9e80')
          .letterSpacing(2)
          .textAlign(TextAlign.Center)
          .width('100%')
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  buildCandidateRow(e: Exhibit, candidate: boolean) {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(e.titleZh)
          .fontSize(14)
          .fontWeight(candidate ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(candidate ? '#f5e6c8' : '#5a5a6a')
        Text(e.artist + ' · ' + e.year)
          .fontSize(11)
          .fontColor(candidate ? '#b9a57a' : '#4a4a5a')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(candidate ? '候选' : '已排除')
        .fontSize(11)
        .fontColor(candidate ? '#0a0a1a' : '#8a8a9a')
        .backgroundColor(candidate ? '#d4b678' : '#33d4b678')
        .padding({ left: 10, right: 10, top: 3, bottom: 3 })
        .borderRadius(10)
    }
    .width('100%')
    .padding({ left: 14, right: 12, top: 10, bottom: 10 })
    .backgroundColor(candidate ? '#E612122a' : '#660e0e1c')
    .borderColor(candidate ? '#55d4b678' : '#22d4b678')
    .borderWidth(1)
    .borderRadius(8)
  }

  private candidateCountLabel(): string {
    const n: number = candidateExhibitIds(this.discoveredClueIds).length;
    return `${n} / ${DAVID_EXHIBITS.length}`;
  }

  private footerHint(): string {
    const n: number = candidateExhibitIds(this.discoveredClueIds).length;
    if (n <= 1) return '线索已足够。走到候选画作前完成指认。';
    if (n <= 3) return '接近真相。继续收集线索以缩小范围。';
    return '线索尚不足。继续在馆内探索。';
  }
}
