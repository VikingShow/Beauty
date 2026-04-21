import { Exhibit, findExhibit } from '../scenes/Exhibits';

/**
 * 展品介绍卡：顶部居中显示，走近触发、离开淡出。
 * 使用 @Prop exhibitId 驱动，空串表示隐藏。
 * 内部缓存"上一次非空展品"的数据，保证淡出过程中文字不会瞬间清空。
 */
@Component
export struct ExhibitCard {
  @Prop @Watch('onIdChange') exhibitId: string = '';
  @State private displayedId: string = '';
  @State private cardOpacity: number = 0;

  aboutToAppear(): void {
    if (this.exhibitId !== '') {
      this.displayedId = this.exhibitId;
      this.cardOpacity = 1;
    }
  }

  onIdChange(): void {
    const hasId: boolean = this.exhibitId !== '';
    if (hasId && this.exhibitId !== this.displayedId && this.displayedId !== '') {
      // 切换：先淡出旧卡 → 换 id → 淡入新卡
      animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
        this.cardOpacity = 0;
      });
      setTimeout(() => {
        this.displayedId = this.exhibitId;
        animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
          this.cardOpacity = 1;
        });
      }, 180);
    } else if (!hasId) {
      animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.cardOpacity = 0;
      });
    } else if (hasId && this.cardOpacity === 0) {
      this.displayedId = this.exhibitId;
      animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
        this.cardOpacity = 1;
      });
    }
  }

  build() {
    Column() {
      if (this.displayedId !== '') {
        this.Card(findExhibit(this.displayedId))
      }
    }
    .width('100%')
    .opacity(this.cardOpacity)
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  Card(e: Exhibit | undefined) {
    if (e !== undefined) {
      Column({ space: 6 }) {
        // 顶部：中文标题（大字）
        Text(e.titleZh)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f5e6c8')
          .letterSpacing(2)

        // 副标：英文标题 · 年代
        Text(`${e.titleEn}  ·  ${e.year}`)
          .fontSize(12)
          .fontColor('#d4b67899')
          .letterSpacing(1)

        // 分隔线
        Divider()
          .strokeWidth(1)
          .color('#d4b67855')
          .margin({ top: 4, bottom: 4 })

        // 艺术家 · 流派 · 尺寸（行内元信息）
        Row({ space: 10 }) {
          Text(e.artist)
            .fontSize(13)
            .fontColor('#e8d9b0')
            .fontWeight(FontWeight.Medium)
          Text('·').fontSize(13).fontColor('#66666688')
          Text(e.school)
            .fontSize(12)
            .fontColor('#b9a57a')
          Text('·').fontSize(13).fontColor('#66666688')
          Text(e.sizeCm)
            .fontSize(12)
            .fontColor('#b9a57a')
        }

        // 导览文字
        Text(e.description)
          .fontSize(14)
          .fontColor('#e8e4d6')
          .lineHeight(22)
          .margin({ top: 6 })
      }
      .width(520)
      .padding({ left: 20, right: 20, top: 14, bottom: 16 })
      .backgroundColor('#1a1a2eEE')
      .borderColor('#d4b678')
      .borderWidth(1)
      .borderRadius(12)
      .alignItems(HorizontalAlign.Start)
    }
  }
}
