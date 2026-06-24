import { PresetScene, PRESET_SCENES, SceneType } from '../utils/GalleryTypes';
import { ModelManager } from '../utils/ModelManager';

@Component
export struct SceneSelector {
  @Prop selectedSceneId: string = '';
  @State importing: boolean = false;
  @State importError: string = '';
  modelManager: ModelManager | undefined = undefined;
  onSceneSelected: (uri: Resource | string, type: SceneType, id: string) => void = () => {};

  async importCustomScene(): Promise<void> {
    if (this.modelManager === undefined) return;
    this.importing = true;
    this.importError = '';
    try {
      const path: string = await this.modelManager.pickModelFile();
      const name: string = path.split('/').pop() ?? 'custom_scene';
      this.onSceneSelected(path, 'gltf', 'custom_' + Date.now().toString(36));
    } catch (e) {
      const msg: string = e instanceof Error ? e.message : JSON.stringify(e);
      this.importError = msg;
    } finally {
      this.importing = false;
    }
  }

  build() {
    Column({ space: 16 }) {
      Text('选择展厅')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f5e6c8')
        .letterSpacing(4)

      Text('预设场景')
        .fontSize(13)
        .fontColor('#8a8a9a')
        .letterSpacing(2)

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
        ForEach(PRESET_SCENES, (scene: PresetScene) => {
          Column({ space: 6 }) {
            Column() {
              Text(scene.nameZh.substring(0, 4))
                .fontSize(18)
                .fontColor(this.selectedSceneId === scene.id ? '#0a0a1a' : '#f5e6c8')
                .fontWeight(FontWeight.Medium)
            }
            .width(120)
            .height(72)
            .borderRadius(10)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.selectedSceneId === scene.id ? '#d4b678' : '#1a1a2e')
            .border({
              width: this.selectedSceneId === scene.id ? 2 : 1,
              color: this.selectedSceneId === scene.id ? '#d4b678' : '#4a4a5a',
              style: BorderStyle.Solid,
              radius: 10
            })
            .onClick(() => {
              this.selectedSceneId = scene.id;
              this.onSceneSelected(scene.uri, scene.type, scene.id);
            })

            Text(scene.nameZh)
              .fontSize(11)
              .fontColor('#8a8a9a')
              .maxLines(1)
          }
          .width(120)
        }, (scene: PresetScene) => scene.id)
      }

      Divider().strokeWidth(1).color('#333344').width(200)

      Column({ space: 8 }) {
        Text('自定义场景')
          .fontSize(13)
          .fontColor('#8a8a9a')
          .letterSpacing(2)

        Button('导入 .glb 场景模型', { type: ButtonType.Capsule })
          .height(40)
          .fontSize(14)
          .fontColor('#d4b678')
          .backgroundColor('#1a1a2e')
          .borderColor('#d4b678')
          .borderWidth(1)
          .enabled(!this.importing)
          .onClick(() => {
            this.importCustomScene();
          })

        if (this.importing) {
          LoadingProgress().width(24).height(24).color('#d4b678')
        }

        if (this.importError !== '') {
          Text(this.importError)
            .fontSize(11)
            .fontColor('#ff6b6b')
            .maxLines(2)
        }
      }
    }
    .padding(20)
    .backgroundColor('#0f0f1f')
    .borderRadius(16)
    .border({ width: 1, color: '#33334488', style: BorderStyle.Solid, radius: 16 })
  }
}
