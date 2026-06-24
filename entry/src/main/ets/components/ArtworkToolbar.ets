import { PlacedArtwork } from '../utils/GalleryTypes';

@Component
export struct ArtworkToolbar {
  @Prop artworks: PlacedArtwork[] = [];
  @Prop importing: boolean = false;
  @Prop importError: string = '';
  @Prop selectedId: string = '';
  @State collapsed: boolean = false;
  onAdd: () => void = () => {};
  onSelect: (id: string) => void = () => {};
  onDelete: (id: string) => void = () => {};

  build() {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Text('作品 ' + this.artworks.length)
          .fontSize(13)
          .fontColor('#d4b678')
          .letterSpacing(2)
        Text(this.collapsed ? '▼' : '▲')
          .fontSize(10)
          .fontColor('#8a8a9a')
      }
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor('#E61a1a2e')
      .borderRadius(10)
      .border({ width: 1, color: '#4a4a5a', style: BorderStyle.Solid, radius: 10 })
      .onClick(() => { this.collapsed = !this.collapsed; })

      if (!this.collapsed) {
        Button('添加作品 (.glb)')
          .height(36)
          .fontSize(13)
          .width('100%')
          .backgroundColor('#d4b678')
          .fontColor('#0a0a1a')
          .enabled(!this.importing)
          .onClick(() => { this.onAdd(); })

        if (this.importing) {
          Row() {
            LoadingProgress().width(16).height(16).color('#d4b678')
            Text('导入中...')
              .fontSize(11)
              .fontColor('#8a8a9a')
              .margin({ left: 6 })
          }
        }

        if (this.importError !== '') {
          Text(this.importError)
            .fontSize(10)
            .fontColor('#ff6b6b')
            .maxLines(2)
            .width('100%')
        }

        if (this.artworks.length > 0) {
          Divider().strokeWidth(1).color('#333344')
          Scroll() {
            Column({ space: 4 }) {
              ForEach(this.artworks, (art: PlacedArtwork) => {
                Row({ space: 8 }) {
                  Column() {
                    Text(art.modelName.substring(0, 12))
                      .fontSize(12)
                      .fontColor(this.selectedId === art.id ? '#0a0a1a' : '#f5e6c8')
                      .maxLines(1)
                    Text('(' + art.position.x.toFixed(1) + ', ' + art.position.z.toFixed(1) + ')')
                      .fontSize(9)
                      .fontColor('#6a6a7a')
                  }
                  .layoutWeight(1)

                  Row() {
                    Text('⊙')
                      .fontSize(12)
                      .fontColor(this.selectedId === art.id ? '#0a0a1a' : '#8a8a9a')
                  }
                  .width(24).height(24)
                  .borderRadius(12)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor(this.selectedId === art.id ? '#d4b67844' : '#1a1a2e')
                  .onClick(() => { this.onSelect(art.id); })

                  Row() {
                    Text('×')
                      .fontSize(12)
                      .fontColor('#ff6b6b')
                  }
                  .width(24).height(24)
                  .borderRadius(12)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor('#1a1a2e')
                  .onClick(() => { this.onDelete(art.id); })
                }
                .width('100%')
                .padding({ left: 8, right: 8, top: 6, bottom: 6 })
                .backgroundColor(this.selectedId === art.id ? '#d4b67833' : '#1a1a2e')
                .borderRadius(6)
              }, (art: PlacedArtwork) => art.id)
            }
          }
          .height(200)
          .width('100%')
        }
      }
    }
    .width(160)
    .padding(8)
    .backgroundColor('#0f0f1f88')
    .borderRadius(12)
  }
}
