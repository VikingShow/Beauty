import { Exhibit, findExhibit } from '../scenes/Exhibits';
import { Clue, clueForExhibit } from '../scenes/Clues';

/**
 * 观察模态：点击 ExhibitCard 的"🔍 深入观察"触发。
 * - 有线索且未收集：展示发现叙述 + 窃语 + "收入笔记"按钮
 * - 有线索已收集：展示同样内容 + "已收入笔记"（禁用）
 * - 无线索：展示"此画今夜静默如常"
 *
 * 通过 @Prop visible 控制显隐，@Watch 触发淡入淡出。
 */
@Component
export struct ObservationModal {
  @Prop @Watch('onVisibleChange') visible: boolean = false;
  @Prop exhibitId: string = '';
  @Prop alreadyCollected: boolean = false;
  onClose: () => void = () => {};
  onCollect: (clueId: string) => void = () => {};

  @State private backdropOpacity: number = 0;
  @State private contentOpacity: number = 0;
  @State private contentOffsetY: number = 16;

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
      this.contentOffsetY = 16;
    }
  }

  build() {
    if (this.visible) {
      Stack() {
        // 背景蒙层
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#000000D8')
          .opacity(this.backdropOpacity)
          .onClick(() => {
            this.onClose();
          })

        // 中心卡片
        Column() {
          this.buildContent()
        }
        .width(560)
        .padding({ left: 32, right: 32, top: 28, bottom: 28 })
        .backgroundColor('#0a0a1aF2')
        .borderColor('#d4b67888')
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
  buildContent() {
    Column({ space: 16 }) {
      // 头部：画作名
      Column({ space: 2 }) {
        Text(this.getTitleZh())
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#d4b678')
          .letterSpacing(2)
        Text(this.getTitleEn())
          .fontSize(11)
          .fontColor('#8a8a9a')
          .letterSpacing(1)
      }

      Divider()
        .strokeWidth(1)
        .color('#d4b67844')
        .margin({ top: 2, bottom: 2 })

      // 正文：有线索 / 无线索 分支
      if (this.hasClue()) {
        Text('🕯  ' + this.getOrderLabel())
          .fontSize(13)
          .fontColor('#b9a57a')
          .letterSpacing(4)

        Text(this.getDetailText())
          .fontSize(14)
          .fontColor('#c9c9b4')
          .lineHeight(24)
          .textAlign(TextAlign.Center)

        // 窃语框
        Column() {
          Text('「 ' + this.getWhisper() + ' 」')
            .fontSize(17)
            .fontColor('#f5e6c8')
            .fontStyle(FontStyle.Italic)
            .lineHeight(30)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 16, bottom: 16 })
        .backgroundColor('#1a1a2eAA')
        .borderColor('#d4b67855')
        .borderWidth(1)
        .borderRadius(8)
        .margin({ top: 4, bottom: 4 })

        // 按钮组
        Row({ space: 16 }) {
          Button(this.alreadyCollected ? '✓ 已收入笔记' : '收入笔记', { type: ButtonType.Capsule })
            .enabled(!this.alreadyCollected)
            .fontSize(14)
            .height(40)
            .backgroundColor(this.alreadyCollected ? '#1a1a2e' : '#d4b678')
            .fontColor(this.alreadyCollected ? '#8a8a9a' : '#0a0a1a')
            .borderColor('#d4b678')
            .borderWidth(1)
            .padding({ left: 24, right: 24 })
            .onClick(() => {
              const c: Clue | undefined = clueForExhibit(this.exhibitId);
              if (c !== undefined && !this.alreadyCollected) {
                this.onCollect(c.id);
              }
            })

          Button('关闭', { type: ButtonType.Capsule })
            .fontSize(14)
            .height(40)
            .backgroundColor('#1a1a2e99')
            .fontColor('#d4b678')
            .borderColor('#d4b67855')
            .borderWidth(1)
            .padding({ left: 24, right: 24 })
            .onClick(() => {
              this.onClose();
            })
        }
        .margin({ top: 8 })
      } else {
        // 无线索画
        Text('你静静端详了一番。')
          .fontSize(14)
          .fontColor('#c9c9b4')
          .lineHeight(24)
          .textAlign(TextAlign.Center)
          .margin({ top: 8 })

        Text('这幅画今夜静默如常。')
          .fontSize(14)
          .fontColor('#8a8a9a')
          .lineHeight(24)
          .textAlign(TextAlign.Center)

        Button('离开', { type: ButtonType.Capsule })
          .fontSize(14)
          .height(40)
          .backgroundColor('#1a1a2e99')
          .fontColor('#d4b678')
          .borderColor('#d4b67855')
          .borderWidth(1)
          .padding({ left: 44, right: 44 })
          .margin({ top: 12 })
          .onClick(() => {
            this.onClose();
          })
      }
    }
    .alignItems(HorizontalAlign.Center)
  }

  private hasClue(): boolean {
    return clueForExhibit(this.exhibitId) !== undefined;
  }

  private getTitleZh(): string {
    const e: Exhibit | undefined = findExhibit(this.exhibitId);
    return e !== undefined ? e.titleZh : '';
  }

  private getTitleEn(): string {
    const e: Exhibit | undefined = findExhibit(this.exhibitId);
    return e !== undefined ? e.titleEn : '';
  }

  private getOrderLabel(): string {
    const c: Clue | undefined = clueForExhibit(this.exhibitId);
    return c !== undefined ? c.orderLabel : '';
  }

  private getDetailText(): string {
    const c: Clue | undefined = clueForExhibit(this.exhibitId);
    return c !== undefined ? c.detailText : '';
  }

  private getWhisper(): string {
    const c: Clue | undefined = clueForExhibit(this.exhibitId);
    return c !== undefined ? c.whisper : '';
  }
}
