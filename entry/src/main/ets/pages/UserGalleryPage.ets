import { router } from '@kit.ArkUI';
import {
  Camera,
  Node
} from '@kit.ArkGraphics3D';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GalleryEditor, EditorMode } from '../utils/GalleryEditor';
import { ModelManager } from '../utils/ModelManager';
import { LayoutSerializer } from '../utils/LayoutSerializer';
import { SceneSelector } from '../components/SceneSelector';
import { ArtworkToolbar } from '../components/ArtworkToolbar';
import { PropertyPanel } from '../components/PropertyPanel';
import { Joystick } from '../components/Joystick';
import { FirstPersonCameraController } from '../controllers/FirstPersonCameraController';
import { PlacedArtwork, SceneType, Position3 } from '../utils/GalleryTypes';

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
  @State private dragging: boolean = false;
  @State private toastMessage: string = '';
  @State private toastOpacity: number = 0;

  private editor: GalleryEditor = new GalleryEditor();
  private controller: FirstPersonCameraController = new FirstPersonCameraController(undefined);
  private modelManager: ModelManager = new ModelManager();
  private layoutSerializer: LayoutSerializer = new LayoutSerializer();

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

  private getSelectedArtworkId(): string {
    const sel: PlacedArtwork | null = this.editor.getSelectedArtwork();
    return sel !== null ? sel.id : '';
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
      const msg: string = e instanceof Error ? e.message : JSON.stringify(e);
      this.errorMsg = msg;
      hilog.error(DOMAIN, 'UserGalleryPage', 'load failed: %{public}s', this.errorMsg);
    }
  }

  private async importArtwork(): Promise<void> {
    this.importing = true;
    this.importError = '';
    try {
      const path: string = await this.modelManager.pickArtworkFile();
      const artwork = await this.editor.importArtwork(path);
      this.showToast('已导入: ' + artwork.modelName);
    } catch (e) {
      const msg: string = e instanceof Error ? e.message : JSON.stringify(e);
      this.importError = msg;
    } finally {
      this.importing = false;
    }
  }

  private async import3DGS(): Promise<void> {
    this.importing = true;
    this.importError = '';
    try {
      const path: string = await this.modelManager.pickGSFile();
      await this.editor.load3DGSScene(path);
      this.showToast('已导入 3DGS 场景');
    } catch (e) {
      const msg: string = e instanceof Error ? e.message : JSON.stringify(e);
      this.importError = msg;
    } finally {
      this.importing = false;
    }
  }

  private showToast(msg: string): void {
    this.toastMessage = msg;
    this.toastOpacity = 1;
    setTimeout(() => {
      animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
        this.toastOpacity = 0;
      });
    }, 2000);
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

  private async handleDragMove(e: GestureEvent): Promise<void> {
    const hitPos: Position3 | null = await this.editor.raycastHitPosition(
      this.tapX + e.offsetX,
      this.tapY + e.offsetY,
      100, 100
    );
    if (hitPos !== null) {
      this.editor.moveSelectedOnGround(hitPos.x, hitPos.z);
    }
  }

  private confirmPlace(): void {
    this.editor.setMode('navigate');
    this.editor.deselectArtwork();
  }

  private resetCamera(): void {
    const cam = this.editor.getCamera();
    if (cam !== undefined) {
      cam.position = { x: 0, y: 1.65, z: 5 };
      cam.rotation = { x: 0, y: 0, z: 0, w: 1 };
      cam.fov = 70 * Math.PI / 180;
      this.showToast('视角已重置');
    }
  }

  private async saveLayout(): Promise<void> {
    const artworks = this.editor.getPlacedArtworks();
    const layout = this.layoutSerializer.createEmpty(
      'My Exhibition ' + Date.now().toString(36),
      this.selectedSceneId,
      'gltf'
    );
    layout.placedArtworks = artworks;
    const cam = this.editor.getCamera();
    if (cam !== undefined) {
      const camPos = cam.position;
      const camRot = cam.rotation;
      layout.cameraPosition = { x: camPos.x, y: camPos.y, z: camPos.z };
      layout.cameraRotation = { x: camRot.x, y: camRot.y, z: camRot.z, w: camRot.w };
    }
    await this.layoutSerializer.save(getContext(this), layout);
    hilog.info(DOMAIN, 'UserGalleryPage', 'layout saved: %{public}s', layout.id);
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#0a0a1a')

      if (this.sceneReady) {
        Component3D({ scene: this.editor.getScene() })
          .width('100%')
          .height('100%')
          .backgroundColor('#0a0a1a')
          .opacity(this.sceneOpacity)
          .gesture(
            GestureGroup(GestureMode.Parallel,
              PanGesture({ fingers: 1 })
                .onActionStart(() => {
                  if (this.editorMode === 'edit') {
                    this.dragging = true;
                  } else {
                    this.controller.onPanStart();
                  }
                })
                .onActionUpdate((e: GestureEvent) => {
                  if (this.dragging) {
                    this.handleDragMove(e);
                  } else {
                    this.controller.onPanUpdate(e.offsetX, e.offsetY);
                  }
                })
                .onActionEnd(() => {
                  if (this.dragging) {
                    this.dragging = false;
                  } else {
                    this.controller.onPanEnd();
                  }
                }),
              PinchGesture()
                .onActionUpdate((e: PinchGestureEvent) => {
                  const cam = this.editor.getCamera();
                  if (cam !== undefined) {
                    const fovDelta = (e.scale - 1) * 20;
                    const newFov = Math.max(30, Math.min(90, cam.fov * 180 / Math.PI - fovDelta));
                    cam.fov = newFov * Math.PI / 180;
                  }
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

          if (this.editorMode === 'edit') {
            Text('[ 编辑模式 - 拖拽移动 ]')
              .fontSize(12)
              .fontColor('#8aaa6a')
              .fontWeight(FontWeight.Bold)
          } else {
            Text('[ 浏览模式 - 点击选择 ]')
              .fontSize(12)
              .fontColor('#8a8a9a')
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
          ArtworkToolbar({
            artworks: this.editor.getPlacedArtworks(),
            importing: this.importing,
            importError: this.importError,
            selectedId: this.getSelectedArtworkId(),
            onAdd: () => { this.importArtwork(); },
            onSelect: (id: string) => { this.editor.selectArtworkById(id); },
            onDelete: (id: string) => {
              this.editor.selectArtworkById(id);
              this.editor.removeSelectedArtwork();
            }
          })

          Button('导入3DGS场景')
            .fontSize(13)
            .height(36)
            .width(160)
            .backgroundColor('#2a1a3e')
            .fontColor('#c4a6e8')
            .borderColor('#6a4a8a')
            .borderWidth(1)
            .enabled(this.sceneReady && !this.importing)
            .onClick(() => { this.import3DGS(); })

          Button('切换展厅')
            .fontSize(14)
            .height(36)
            .width(160)
            .backgroundColor('#1a1a2e')
            .fontColor('#8a8a9a')
            .borderColor('#4a4a5a')
            .borderWidth(1)
            .onClick(() => {
              this.sceneSelectorVisible = true;
            })

          Button('保存布展')
            .fontSize(13)
            .height(36)
            .width(160)
            .backgroundColor('#1a3a2e')
            .fontColor('#8ad4a8')
            .borderColor('#4a8a6a')
            .borderWidth(1)
            .enabled(this.sceneReady && this.placedCount > 0)
            .onClick(() => { this.saveLayout(); })

          Button('重置视角')
            .fontSize(13)
            .height(36)
            .width(160)
            .backgroundColor('#1a1a2e')
            .fontColor('#8a8a9a')
            .borderColor('#4a4a5a')
            .borderWidth(1)
            .enabled(this.sceneReady)
            .onClick(() => { this.resetCamera(); })
        }
        .position({ x: '100%', y: '50%' })
        .markAnchor({ x: 180, y: 120 })

        if (this.propertyVisible && this.selectedName !== '') {
          PropertyPanel({
            name: this.selectedName,
            posX: this.posX,
            posY: this.posY,
            posZ: this.posZ,
            rotY: this.rotY,
            scaleVal: this.scaleVal,
            onNudge: (dx: number, dy: number, dz: number) => { this.editor.nudgeSelected(dx, dy, dz); },
            onRotate: (deg: number) => { this.editor.rotateSelectedY(deg); },
            onScale: (factor: number) => { this.editor.scaleSelected(factor); },
            onConfirm: () => { this.confirmPlace(); },
            onDelete: () => { this.editor.removeSelectedArtwork(); },
            onCancel: () => { this.editor.deselectArtwork(); }
          })
            .position({ x: '100%', y: '50%' })
            .markAnchor({ x: 180, y: 100 })
        }
      }

      if (this.sceneSelectorVisible) {
        Column() {
          SceneSelector({
            selectedSceneId: this.selectedSceneId,
            modelManager: this.modelManager,
            onSceneSelected: (uri: Resource | string, type: SceneType, id: string) => {
              this.onSceneSelected(uri, type, id);
            }
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

      if (this.toastOpacity > 0) {
        Text(this.toastMessage)
          .fontSize(14)
          .fontColor('#ffffff')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor('#d4b678')
          .borderRadius(8)
          .position({ x: '50%', y: 80 })
          .markAnchor({ x: 80, y: 0 })
          .opacity(this.toastOpacity)
      }
    }
    .width('100%')
    .height('100%')
  }
}
