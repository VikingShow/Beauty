import { Camera } from '@kit.ArkGraphics3D';

/**
 * 相机控制器基类。每个 3D 场景页面持有一个具体子类实例，
 * 在 Component3D 的 Pan/Pinch/Tap 手势中转发给 controller。
 *
 * 子类按需覆盖 onXxx 方法，修改 this.camera 的 position / rotation / fov。
 */
export class CameraController {
  protected camera: Camera | undefined = undefined;

  attach(camera: Camera): void {
    this.camera = camera;
    this.onAttached();
  }

  detach(): void {
    this.camera = undefined;
  }

  getPositionX(): number {
    return this.camera?.position?.x ?? 0;
  }
  getPositionY(): number {
    return this.camera?.position?.y ?? 0;
  }
  getPositionZ(): number {
    return this.camera?.position?.z ?? 0;
  }
  getRotationX(): number {
    return this.camera?.rotation?.x ?? 0;
  }
  getRotationY(): number {
    return this.camera?.rotation?.y ?? 0;
  }
  getRotationZ(): number {
    return this.camera?.rotation?.z ?? 0;
  }
  getRotationW(): number {
    return this.camera?.rotation?.w ?? 1;
  }

  protected onAttached(): void {
    // 子类可重写：初始帧 apply 相机状态
  }

  onPanStart(): void {}

  onPanUpdate(dx: number, dy: number): void {}

  onPanEnd(): void {}

  onPinchStart(): void {}

  onPinchUpdate(scale: number): void {}

  onPinchEnd(): void {}

  onTap(x: number, y: number): void {}
}
