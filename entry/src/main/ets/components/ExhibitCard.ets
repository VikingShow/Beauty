import { Exhibit, findExhibit } from '../scenes/Exhibits';

/**
 * 展品介绍卡：顶部居中显示，走近触发、离开淡出。
 * 使用 @Prop exhibitId 驱动，空串表示隐藏。
 * 内部缓存"上一次非空展品"的字段，保证淡出过程中文字不会瞬间清空。
 */
@Component
export struct ExhibitCard {
  @Prop @Watch('onIdChange') exhibitId: string = '';

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
        Column({ space: 6 }) {
          Text(this.titleZh)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f5e6c8')
            .letterSpacing(2)

          Text(this.titleEn + '  ·  ' + this.year)
            .fontSize(12)
            .fontColor('#d4b67899')
            .letterSpacing(1)

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
    .width('100%')
    .opacity(this.cardOpacity)
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
