import { Exhibit, findExhibit } from '../scenes/Exhibits';

/**
 * 展品介绍卡：顶部居中显示，走近触发、离开淡出。
 * 使用 @Prop exhibitId 驱动，空串表示隐藏。
 * 内部缓存"上一次非空展品"的字段，保证淡出过程中文字不会瞬间清空。
 *
 * 支持"收起 / 展开"：右上角 chevron 按钮，收起后只保留标题栏。
 * 切换画作时自动重置为展开态。
 *
 * clueState:
 *   'none'      - 这幅画没有线索，按钮显示为中性"端详"
 *   'available' - 有线索未收集，按钮金色高亮"深入观察"
 *   'collected' - 线索已收集，按钮暗金"已观察"
 */
@Component
export struct ExhibitCard {
  @Prop @Watch('onIdChange') exhibitId: string = '';
  @Prop clueState: string = 'none';
  onObserve: () => void = () => {};

  // 显示层状态：缓存上一次展品的全部字段，淡出时文字不消失
  @State private titleZh: string = '';
  @State private titleEn: string = '';
  @State private artist: string = '';
  @State private year: string = '';
  @State private sizeCm: string = '';
  @State private school: string = '';
  @State private description: string = '';
  @State private hasContent: boolean = false;

  @State private cardOpacity: number = 0;
  @State private collapsed: boolean = false;

  aboutToAppear(): void {
    if (this.exhibitId !== '') {
      this.loadFields(this.exhibitId);
      this.cardOpacity = 1;
    }
  }

  private loadFields(id: string): void {
    const e: Exhibit | undefined = findExhibit(id);
    if (e === undefined) {
      this.hasContent = false;
      return;
    }
    this.titleZh = e.titleZh;
    this.titleEn = e.titleEn;
    this.artist = e.artist;
    this.year = e.year;
    this.sizeCm = e.sizeCm;
    this.school = e.school;
    this.description = e.description;
    this.hasContent = true;
  }

  onIdChange(): void {
    const hasId: boolean = this.exhibitId !== '';
    // 切换画作时重置展开态
    this.collapsed = false;
    if (hasId && this.hasContent) {
      // 切换：先淡出旧卡 → 换内容 → 淡入新卡
      animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
        this.cardOpacity = 0;
      });
      setTimeout(() => {
        this.loadFields(this.exhibitId);
        animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
          this.cardOpacity = 1;
        });
      }, 180);
    } else if (!hasId) {
      animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.cardOpacity = 0;
      });
    } else if (hasId && !this.hasContent) {
      this.loadFields(this.exhibitId);
      animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
        this.cardOpacity = 1;
      });
    }
  }

  build() {
    Column() {
      if (this.hasContent) {
        if (this.collapsed) {
          this.buildCollapsedBanner()
        } else {
          this.buildFullCard()
        }
      }
    }
    .width('100%')
    .opacity(this.cardOpacity)
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  buildCollapsedBanner() {
    Row({ space: 10 }) {
      Text(this.titleZh)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#f5e6c8')
        .letterSpacing(2)

      Image($r('app.media.icon_chevron'))
        .width(16)
        .height(16)
        .fillColor('#d4b678')
    }
    .padding({ left: 18, right: 14, top: 10, bottom: 10 })
    .backgroundColor('#1a1a2eF0')
    .borderColor('#d4b678')
    .borderWidth(1)
    .borderRadius(20)
    .onClick(() => {
      this.collapsed = false;
    })
  }

  @Builder
  buildFullCard() {
    Column({ space: 6 }) {
      // 头部：标题 + 右上角收起按钮
      Row() {
        Column({ space: 2 }) {
          Text(this.titleZh)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f5e6c8')
            .letterSpacing(2)

          Text(this.titleEn + '  ·  ' + this.year)
            .fontSize(12)
            .fontColor('#d4b67899')
            .letterSpacing(1)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 收起按钮（chevron 朝上 = 上推隐藏）
        Row() {
          Image($r('app.media.icon_chevron'))
            .width(18)
            .height(18)
            .fillColor('#d4b678')
            .rotate({ angle: 180 })
        }
        .width(32)
        .height(32)
        .justifyContent(FlexAlign.Center)
        .borderRadius(16)
        .onClick(() => {
          this.collapsed = true;
        })
      }
      .width('100%')

      Divider()
        .strokeWidth(1)
        .color('#d4b67855')
        .margin({ top: 4, bottom: 4 })

      Row({ space: 10 }) {
        Text(this.artist)
          .fontSize(13)
          .fontColor('#e8d9b0')
          .fontWeight(FontWeight.Medium)
        Text('·').fontSize(13).fontColor('#66666688')
        Text(this.school)
          .fontSize(12)
          .fontColor('#b9a57a')
        Text('·').fontSize(13).fontColor('#66666688')
        Text(this.sizeCm)
          .fontSize(12)
          .fontColor('#b9a57a')
      }

      Text(this.description)
        .fontSize(14)
        .fontColor('#e8e4d6')
        .lineHeight(22)
        .margin({ top: 6 })

      // 观察按钮
      Row() {
        Button({ type: ButtonType.Capsule }) {
          Row({ space: 8 }) {
            if (this.clueState === 'collected') {
              Image($r('app.media.icon_check'))
                .width(14).height(14)
                .fillColor(this.observeFg())
            } else {
              Image($r('app.media.icon_search'))
                .width(14).height(14)
                .fillColor(this.observeFg())
            }
            Text(this.observeText())
              .fontSize(13)
              .fontColor(this.observeFg())
          }
          .padding({ left: 18, right: 18, top: 6, bottom: 6 })
        }
        .enabled(this.clueState !== 'collected')
        .height(34)
        .backgroundColor(this.observeBg())
        .borderColor(this.observeBorder())
        .borderWidth(1)
        .onClick(() => {
          this.onObserve();
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ top: 10 })
    }
    .width(520)
    .padding({ left: 20, right: 14, top: 12, bottom: 14 })
    .backgroundColor('#1a1a2eF0')
    .borderColor('#d4b678')
    .borderWidth(1)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  private observeText(): string {
    if (this.clueState === 'collected') return '已观察';
    if (this.clueState === 'available') return '深入观察';
    return '端详';
  }

  private observeBg(): string {
    if (this.clueState === 'available') return '#d4b678';
    return '#1a1a2e';
  }

  private observeFg(): string {
    if (this.clueState === 'available') return '#0a0a1a';
    if (this.clueState === 'collected') return '#b9a57a';
    return '#d4b678';
  }

  private observeBorder(): string {
    if (this.clueState === 'available') return '#d4b678';
    if (this.clueState === 'collected') return '#b9a57a88';
    return '#d4b67866';
  }
}
