import { router } from '@kit.ArkUI';
import {
  Camera,
  Node
} from '@kit.ArkGraphics3D';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GalleryEditor, EditorMode } from '../utils/GalleryEditor';
import { ModelManager } from '../utils/ModelManager';
import { SceneSelector } from '../components/SceneSelector';
import { Joystick } from '../components/Joystick';
import { FirstPersonCameraController } from '../controllers/FirstPersonCameraController';
import { PlacedArtwork, SceneType } from '../utils/GalleryTypes';

const DOMAIN = 0x0105;

@Entry
@Component
struct UserGalleryPage {
  @State private sceneReady: boolean = false;
  @State private errorMsg: string = '';
  @State private loadingOpacity: number = 1;
  @State private sceneOpacity: number = 0;
  @State private sceneSelectorVisible: boolean = true;
  @State private selectedSceneId: string = '';
  @State private editorMode: EditorMode = 'navigate';
  @State private placedCount: number = 0;
  @State private selectedName: string = '';
  @State private importError: string = '';
  @State private importing: boolean = false;
  @State private posX: number = 0;
  @State private posY: number = 0;
  @State private posZ: number = 0;
  @State private rotY: number = 0;
  @State private scaleVal: number = 1.0;
  @State private propertyVisible: boolean = false;

  private editor: GalleryEditor = new GalleryEditor();
  private controller: FirstPersonCameraController = new FirstPersonCameraController(undefined);
  private modelManager: ModelManager = new ModelManager();

  async aboutToAppear(): Promise<void> {
    this.editor.init(getContext(this));
    this.modelManager.init(getContext(this));
    this.editor.setOnUpdate(() => {
      this.syncEditorState();
    });
    this.controller.setOnUpdate(() => {});
  }

  aboutToDisappear(): void {
    this.editor.destroy();
  }

  private syncEditorState(): void {
    this.editorMode = this.editor.getMode();
    this.placedCount = this.editor.getPlacedArtworks().length;
    const sel: PlacedArtwork | null = this.editor.getSelectedArtwork();
    if (sel !== null) {
      this.selectedName = sel.modelName;
      this.posX = Math.round(sel.position.x * 100) / 100;
      this.posY = Math.round(sel.position.y * 100) / 100;
      this.posZ = Math.round(sel.position.z * 100) / 100;
      const yawDeg: number = Math.round(2 * Math.atan2(sel.rotation.y, sel.rotation.w) * 180 / Math.PI);
      this.rotY = yawDeg;
      this.scaleVal = Math.round(sel.scale.x * 100) / 100;
      this.propertyVisible = true;
    } else {
      this.selectedName = '';
      this.propertyVisible = false;
    }
  }

  private async onSceneSelected(uri: Resource | string, type: SceneType, id: string): Promise<void> {
    this.selectedSceneId = id;
    this.errorMsg = '';
    try {
      await this.editor.loadScene(uri);
      const cam: Camera | undefined = this.editor.getCamera();
      if (cam !== undefined) {
        cam.position = { x: 0, y: 1.65, z: 5 };
        this.controller.attach(cam);
        this.controller.setBounds({ x: -50, z: -50 }, { x: 50, z: 50 });
      }
      this.sceneReady = true;
      this.sceneSelectorVisible = false;
      animateTo({ duration: 400, curve: Curve.EaseInOut }, () => {
        this.sceneOpacity = 1;
      });
      setTimeout(() => {
        animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
          this.loadingOpacity = 0;
        });
      }, 100);
      hilog.info(DOMAIN, 'UserGalleryPage', 'scene loaded OK');
    } catch (e) {
      const err = e as BusinessError;
      this.errorMsg = err.message ?? JSON.stringify(e);
      hilog.error(DOMAIN, 'UserGalleryPage', 'load failed: %{public}s', this.errorMsg);
    }
  }

  private async importArtwork(): Promise<void> {
    this.importing = true;
    this.importError = '';
    try {
      const path: string = await this.modelManager.pickArtworkFile();
      await this.editor.importArtwork(path);
    } catch (e) {
      const err = e as BusinessError;
      this.importError = err.message ?? JSON.stringify(e);
    } finally {
      this.importing = false;
    }
  }

  private tapX: number = 0;
  private tapY: number = 0;

  private async onTapArtwork(): Promise<void> {
    const node: Node | null = await this.editor.raycast(this.tapX, this.tapY, 100, 100);
    if (node !== null) {
      const artworks = this.editor.getPlacedArtworks();
      for (const a of artworks) {
        const scene = this.editor.getScene();
        if (scene !== undefined) {
          const n: Node | null = scene.getNodeByPath(a.nodePath);
          if (n !== null && n === node) {
            this.editor.selectArtworkById(a.id);
            return;
          }
        }
      }
    }
    this.editor.deselectArtwork();
  }

  private confirmPlace(): void {
    this.editor.setMode('navigate');
    this.editor.deselectArtwork();
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#0a0a1a')

      if (this.sceneReady) {
        Component3D({ scene: this.editor.getScene()! })
          .width('100%')
          .height('100%')
          .backgroundColor('#0a0a1a')
          .opacity(this.sceneOpacity)
          .gesture(
            GestureGroup(GestureMode.Parallel,
              PanGesture({ fingers: 1 })
                .onActionStart(() => {
                  this.controller.onPanStart();
                })
                .onActionUpdate((e: GestureEvent) => {
                  this.controller.onPanUpdate(e.offsetX, e.offsetY);
                })
                .onActionEnd(() => {
                  this.controller.onPanEnd();
                })
            )
          )
          .onTouch((e: TouchEvent) => {
            if (e.type === TouchType.Up && e.touches.length > 0) {
              this.tapX = e.touches[0].x;
              this.tapY = e.touches[0].y;
              this.onTapArtwork();
            }
          })
      }

      if (this.errorMsg !== '') {
        Text('加载失败: ' + this.errorMsg)
          .fontColor('#ff6b6b')
          .fontSize(14)
          .position({ x: 20, y: 60 })
      }

      if (!this.sceneSelectorVisible) {
        Row({ space: 12 }) {
          Button('← 返回')
            .fontSize(14)
            .height(36)
            .backgroundColor('#1a1a2e88')
            .fontColor('#ffffff')
            .onClick(() => {
              router.back();
            })

          Text('自由布展  |  已放置: ' + this.placedCount)
            .fontSize(14)
            .fontColor('#d4b678')
            .margin({ left: 12 })

          if (this.editorMode === 'place') {
            Text('[ 放置模式 ]')
              .fontSize(14)
              .fontColor('#8aaa6a')
              .fontWeight(FontWeight.Bold)
          }
        }
        .position({ x: 20, y: 20 })

        Joystick({
          onInput: (x: number, y: number) => {
            this.controller.setMoveInput(x, y);
          }
        })
          .position({ x: 32, y: '100%' })
          .markAnchor({ x: 0, y: 192 })

        Column({ space: 8 }) {
          Button('添加作品')
            .fontSize(14)
            .height(40)
            .width(140)
            .backgroundColor('#d4b678')
            .fontColor('#0a0a1a')
            .enabled(!this.importing)
            .onClick(() => {
              this.importArtwork();
            })

          if (this.importing) {
            LoadingProgress().width(20).height(20).color('#d4b678')
          }

          if (this.importError !== '') {
            Text(this.importError)
              .fontSize(10)
              .fontColor('#ff6b6b')
              .maxLines(2)
              .width(140)
          }

          Button('切换展厅')
            .fontSize(14)
            .height(36)
            .width(140)
            .backgroundColor('#1a1a2e')
            .fontColor('#8a8a9a')
            .borderColor('#4a4a5a')
            .borderWidth(1)
            .onClick(() => {
              this.sceneSelectorVisible = true;
            })
        }
        .position({ x: '100%', y: '50%' })
        .markAnchor({ x: 160, y: 80 })

        if (this.propertyVisible && this.selectedName !== '') {
          Column({ space: 8 }) {
            Text(this.selectedName)
              .fontSize(14)
              .fontColor('#f5e6c8')
              .fontWeight(FontWeight.Medium)

            Row({ space: 6 }) {
              Text('X')
                .fontSize(11)
                .fontColor('#8a8a9a')
                .width(16)
              Button('-')
                .width(28).height(28).fontSize(12)
                .backgroundColor('#1a1a2e').fontColor('#d4b678')
                .onClick(() => { this.editor.nudgeSelected(-0.1, 0, 0); })
              Text(this.posX.toFixed(2))
                .fontSize(11).fontColor('#d4b678').width(50).textAlign(TextAlign.Center)
              Button('+')
                .width(28).height(28).fontSize(12)
                .backgroundColor('#1a1a2e').fontColor('#d4b678')
                .onClick(() => { this.editor.nudgeSelected(0.1, 0, 0); })
            }

            Row({ space: 6 }) {
              Text('Y')
                .fontSize(11)
                .fontColor('#8a8a9a')
                .width(16)
              Button('-')
                .width(28).height(28).fontSize(12)
                .backgroundColor('#1a1a2e').fontColor('#d4b678')
                .onClick(() => { this.editor.nudgeSelected(0, -0.1, 0); })
              Text(this.posY.toFixed(2))
                .fontSize(11).fontColor('#d4b678').width(50).textAlign(TextAlign.Center)
              Button('+')
                .width(28).height(28).fontSize(12)
                .backgroundColor('#1a1a2e').fontColor('#d4b678')
                .onClick(() => { this.editor.nudgeSelected(0, 0.1, 0); })
            }

            Row({ space: 6 }) {
              Text('Z')
                .fontSize(11)
                .fontColor('#8a8a9a')
                .width(16)
              Button('-')
                .width(28).height(28).fontSize(12)
                .backgroundColor('#1a1a2e').fontColor('#d4b678')
                .onClick(() => { this.editor.nudgeSelected(0, 0, -0.1); })
              Text(this.posZ.toFixed(2))
                .fontSize(11).fontColor('#d4b678').width(50).textAlign(TextAlign.Center)
              Button('+')
                .width(28).height(28).fontSize(12)
                .backgroundColor('#1a1a2e').fontColor('#d4b678')
                .onClick(() => { this.editor.nudgeSelected(0, 0, 0.1); })
            }

            Row({ space: 6 }) {
              Text('旋转')
                .fontSize(11)
                .fontColor('#8a8a9a')
                .width(30)
              Button('-15°')
                .height(28).fontSize(11)
                .backgroundColor('#1a1a2e').fontColor('#d4b678')
                .onClick(() => { this.editor.rotateSelectedY(-15); })
              Text(this.rotY + '°')
                .fontSize(11).fontColor('#d4b678').width(50).textAlign(TextAlign.Center)
              Button('+15°')
                .height(28).fontSize(11)
                .backgroundColor('#1a1a2e').fontColor('#d4b678')
                .onClick(() => { this.editor.rotateSelectedY(15); })
            }

            Row({ space: 6 }) {
              Text('缩放')
                .fontSize(11)
                .fontColor('#8a8a9a')
                .width(30)
              Button('-10%')
                .height(28).fontSize(11)
                .backgroundColor('#1a1a2e').fontColor('#d4b678')
                .onClick(() => { this.editor.scaleSelected(0.9); })
              Text(this.scaleVal.toFixed(2) + 'x')
                .fontSize(11).fontColor('#d4b678').width(50).textAlign(TextAlign.Center)
              Button('+10%')
                .height(28).fontSize(11)
                .backgroundColor('#1a1a2e').fontColor('#d4b678')
                .onClick(() => { this.editor.scaleSelected(1.1); })
            }

            Row({ space: 8 }) {
              if (this.editorMode === 'place') {
                Button('确认放置')
                  .height(32).fontSize(13)
                  .backgroundColor('#8aaa6a').fontColor('#0a0a1a')
                  .onClick(() => { this.confirmPlace(); })
              }

              Button('删除')
                .height(32).fontSize(13)
                .backgroundColor('#ff6b6b44').fontColor('#ff6b6b')
                .borderColor('#ff6b6b').borderWidth(1)
                .onClick(() => { this.editor.removeSelectedArtwork(); })

              Button('取消')
                .height(32).fontSize(13)
                .backgroundColor('#1a1a2e').fontColor('#8a8a9a')
                .onClick(() => { this.editor.deselectArtwork(); })
            }
          }
          .padding(14)
          .backgroundColor('#E60f0f1f')
          .borderRadius(12)
          .border({ width: 1, color: '#d4b67888', style: BorderStyle.Solid, radius: 12 })
          .position({ x: '50%', y: '100%' })
          .markAnchor({ x: 120, y: 320 })
        }
      }

      if (this.sceneSelectorVisible) {
        Column() {
          SceneSelector({
            selectedSceneId: this.selectedSceneId
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#0a0a1a')
        .opacity(this.sceneReady ? 0 : 1)
      }

      if (this.loadingOpacity > 0 && !this.sceneSelectorVisible) {
        Column({ space: 20 }) {
          Text('自由布展')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f5e6c8')
            .letterSpacing(6)
          LoadingProgress().width(48).height(48).color('#d4b678')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#0a0a1a')
        .opacity(this.loadingOpacity)
      }
    }
    .width('100%')
    .height('100%')
  }
}
