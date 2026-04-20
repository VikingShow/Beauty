import { CameraController } from './CameraController';
import { Vec3, lerp, smoothstep } from '../utils/Types';
import { Waypoint } from '../scenes/Waypoint';

const PITCH_LIMIT: number = 1.55;
const DEFAULT_PAN_SENSITIVITY: number = 0.004;
const DEFAULT_TELEPORT_MS: number = 700;
const FRAME_MS: number = 16;

interface Quat {
  x: number;
  y: number;
  z: number;
  w: number;
}

/**
 * 第一人称相机：相机位于玩家位置，绕 Y 轴 yaw + 绕 X 轴 pitch 转视角。
 * teleportTo 传送：
 *   - 位置：线性插值（直线"走过去"，符合展厅中人的移动方式）
 *   - 旋转：四元数 slerp（两个 lookAt 焦点的姿态之间走最短弧，无万向锁跳变）
 */
export class FirstPersonCameraController extends CameraController {
  private position: Vec3 = { x: 0, y: 0, z: 5 };
  private yaw: number = 0;
  private pitch: number = 0;

  private yawStart: number = 0;
  private pitchStart: number = 0;

  private readonly panSensitivity: number;
  private animTimer: number | undefined = undefined;

  private focusPoint: Vec3 = { x: 0, y: 0, z: 0 };
  private currentWaypointId: string = '';

  constructor(
    initial: Waypoint | undefined = undefined,
    panSensitivity: number = DEFAULT_PAN_SENSITIVITY
  ) {
    super();
    this.panSensitivity = panSensitivity;
    if (initial !== undefined) {
      this.position = { x: initial.position.x, y: initial.position.y, z: initial.position.z };
      this.currentWaypointId = initial.id;
      this.yaw = this.yawFromLookAt(this.position, this.focusPoint, this.yaw);
      this.pitch = this.pitchFromLookAt(this.position, this.focusPoint);
    }
  }

  getCurrentWaypointId(): string {
    return this.currentWaypointId;
  }

  setFocusPoint(p: Vec3): void {
    this.focusPoint = { x: p.x, y: p.y, z: p.z };
  }

  protected onAttached(): void {
    this.apply();
  }

  onPanStart(): void {
    this.cancelAnimation();
    this.yawStart = this.yaw;
    this.pitchStart = this.pitch;
  }

  onPanUpdate(dx: number, dy: number): void {
    this.yaw = this.yawStart - dx * this.panSensitivity;
    this.pitch = this.pitchStart - dy * this.panSensitivity;
    this.apply();
  }

  teleportTo(target: Waypoint, duration: number = DEFAULT_TELEPORT_MS): void {
    this.cancelAnimation();
    this.currentWaypointId = target.id;

    const endYaw: number = this.yawFromLookAt(target.position, this.focusPoint, this.yaw);
    const endPitch: number = this.pitchFromLookAt(target.position, this.focusPoint);

    if (duration <= 0) {
      this.position = { x: target.position.x, y: target.position.y, z: target.position.z };
      this.yaw = endYaw;
      this.pitch = endPitch;
      this.apply();
      return;
    }

    const startPos: Vec3 = { x: this.position.x, y: this.position.y, z: this.position.z };
    const startQuat: Quat = this.yawPitchToQuat(this.yaw, this.pitch);
    let endQuat: Quat = this.yawPitchToQuat(endYaw, endPitch);
    if (this.quatDot(startQuat, endQuat) < 0) {
      endQuat = { x: -endQuat.x, y: -endQuat.y, z: -endQuat.z, w: -endQuat.w };
    }

    const startTime: number = Date.now();

    const step = (): void => {
      const elapsed: number = Date.now() - startTime;
      const raw: number = Math.min(1, elapsed / duration);
      const t: number = smoothstep(raw);

      this.position.x = lerp(startPos.x, target.position.x, t);
      this.position.y = lerp(startPos.y, target.position.y, t);
      this.position.z = lerp(startPos.z, target.position.z, t);

      const q: Quat = this.quatSlerp(startQuat, endQuat, t);
      if (this.camera !== undefined) {
        this.camera.position.x = this.position.x;
        this.camera.position.y = this.position.y;
        this.camera.position.z = this.position.z;
        this.camera.rotation = { x: q.x, y: q.y, z: q.z, w: q.w };
      }

      if (raw < 1) {
        this.animTimer = setTimeout(step, FRAME_MS);
      } else {
        this.animTimer = undefined;
        this.yaw = endYaw;
        this.pitch = endPitch;
      }
    };
    step();
  }

  private cancelAnimation(): void {
    if (this.animTimer !== undefined) {
      clearTimeout(this.animTimer);
      this.animTimer = undefined;
    }
  }

  private yawFromLookAt(pos: Vec3, target: Vec3, fallback: number): number {
    const dx: number = target.x - pos.x;
    const dz: number = target.z - pos.z;
    const horizDist: number = Math.sqrt(dx * dx + dz * dz);
    if (horizDist < 0.05) {
      return fallback;
    }
    return Math.atan2(-dx, -dz);
  }

  private pitchFromLookAt(pos: Vec3, target: Vec3): number {
    const dx: number = target.x - pos.x;
    const dy: number = target.y - pos.y;
    const dz: number = target.z - pos.z;
    const dist: number = Math.sqrt(dx * dx + dy * dy + dz * dz);
    if (dist < 0.001) {
      return 0;
    }
    const ratio: number = Math.max(-1, Math.min(1, dy / dist));
    return Math.max(-PITCH_LIMIT, Math.min(PITCH_LIMIT, Math.asin(ratio)));
  }

  private yawPitchToQuat(yaw: number, pitch: number): Quat {
    const hy: number = yaw / 2;
    const hp: number = pitch / 2;
    const cy: number = Math.cos(hy);
    const sy: number = Math.sin(hy);
    const cp: number = Math.cos(hp);
    const sp: number = Math.sin(hp);
    return { x: cy * sp, y: sy * cp, z: -sy * sp, w: cy * cp };
  }

  private quatDot(a: Quat, b: Quat): number {
    return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
  }

  private quatSlerp(a: Quat, b: Quat, t: number): Quat {
    const d: number = this.quatDot(a, b);
    if (Math.abs(d) > 0.9995) {
      const x: number = a.x + (b.x - a.x) * t;
      const y: number = a.y + (b.y - a.y) * t;
      const z: number = a.z + (b.z - a.z) * t;
      const w: number = a.w + (b.w - a.w) * t;
      const mag: number = Math.sqrt(x * x + y * y + z * z + w * w);
      return { x: x / mag, y: y / mag, z: z / mag, w: w / mag };
    }
    const omega: number = Math.acos(Math.max(-1, Math.min(1, d)));
    const sinO: number = Math.sin(omega);
    const wa: number = Math.sin((1 - t) * omega) / sinO;
    const wb: number = Math.sin(t * omega) / sinO;
    return {
      x: wa * a.x + wb * b.x,
      y: wa * a.y + wb * b.y,
      z: wa * a.z + wb * b.z,
      w: wa * a.w + wb * b.w
    };
  }

  private apply(): void {
    if (this.camera === undefined) {
      return;
    }
    this.camera.position.x = this.position.x;
    this.camera.position.y = this.position.y;
    this.camera.position.z = this.position.z;

    const yaw: number = this.yaw;
    const pitch: number = Math.max(-PITCH_LIMIT, Math.min(PITCH_LIMIT, this.pitch));
    const q: Quat = this.yawPitchToQuat(yaw, pitch);
    this.camera.rotation = { x: q.x, y: q.y, z: q.z, w: q.w };
  }
}
