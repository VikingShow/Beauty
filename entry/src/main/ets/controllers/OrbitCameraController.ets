import { CameraController } from './CameraController';

const PITCH_LIMIT: number = 1.47;
const DEFAULT_PAN_SENSITIVITY: number = 0.01;
const DEFAULT_MIN_DISTANCE: number = 2;
const DEFAULT_MAX_DISTANCE: number = 15;

/**
 * 轨道相机：相机围绕原点做球面运动。
 * - 单指拖动：yaw / pitch（模型跟手指方向，水平反、垂直正）
 * - 双指捏合：拉近 / 拉远
 */
export class OrbitCameraController extends CameraController {
  private yaw: number = 0;
  private pitch: number = 0;
  private distance: number;

  private yawStart: number = 0;
  private pitchStart: number = 0;
  private distanceStart: number = 0;

  private readonly panSensitivity: number;
  private readonly minDistance: number;
  private readonly maxDistance: number;
  private updateListener: (() => void) | undefined = undefined;

  constructor(
    initialDistance: number = 5,
    panSensitivity: number = DEFAULT_PAN_SENSITIVITY,
    minDistance: number = DEFAULT_MIN_DISTANCE,
    maxDistance: number = DEFAULT_MAX_DISTANCE
  ) {
    super();
    this.distance = initialDistance;
    this.distanceStart = initialDistance;
    this.panSensitivity = panSensitivity;
    this.minDistance = minDistance;
    this.maxDistance = maxDistance;
  }

  protected onAttached(): void {
    this.apply();
  }

  onPanStart(): void {
    this.yawStart = this.yaw;
    this.pitchStart = this.pitch;
  }

  onPanUpdate(dx: number, dy: number): void {
    this.yaw = this.yawStart - dx * this.panSensitivity;
    this.pitch = this.pitchStart + dy * this.panSensitivity;
    this.apply();
  }

  onPinchStart(): void {
    this.distanceStart = this.distance;
  }

  onPinchUpdate(scale: number): void {
    const next: number = this.distanceStart / scale;
    this.distance = Math.max(this.minDistance, Math.min(this.maxDistance, next));
    this.apply();
  }

  getYaw(): number { return this.yaw; }
  getPitch(): number { return this.pitch; }
  getDistance(): number { return this.distance; }

  setOnUpdate(callback: () => void): void {
    this.updateListener = callback;
  }

  getViewYaw(): number {
    const px = this.getPositionX();
    const pz = this.getPositionZ();
    return Math.atan2(-px, pz);
  }

  getViewPitch(): number {
    const px = this.getPositionX();
    const py = this.getPositionY();
    const pz = this.getPositionZ();
    const horiz = Math.sqrt(px * px + pz * pz);
    return Math.atan2(-py, horiz);
  }

  private apply(): void {
    if (this.camera === undefined) {
      return;
    }
    const yaw: number = this.yaw;
    const pitch: number = Math.max(-PITCH_LIMIT, Math.min(PITCH_LIMIT, this.pitch));
    const d: number = this.distance;

    this.camera.position.x = d * Math.cos(pitch) * Math.sin(yaw);
    this.camera.position.y = d * Math.sin(pitch);
    this.camera.position.z = d * Math.cos(pitch) * Math.cos(yaw);

    const hy: number = yaw / 2;
    const hp: number = pitch / 2;
    const cy: number = Math.cos(hy);
    const sy: number = Math.sin(hy);
    const cp: number = Math.cos(hp);
    const sp: number = Math.sin(hp);

    this.camera.rotation = {
      x: -cy * sp,
      y: sy * cp,
      z: sy * sp,
      w: cy * cp
    };

    if (this.updateListener !== undefined) {
      this.updateListener();
    }
  }
}
