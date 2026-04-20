import { CameraController } from './CameraController';
import { Vec3, lerp, smoothstep } from '../utils/Types';
import { Vec2, Waypoint } from '../scenes/Waypoint';

const PITCH_LIMIT: number = 1.55;
const DEFAULT_PAN_SENSITIVITY: number = 0.004;
const DEFAULT_TELEPORT_MS: number = 700;
const FRAME_MS: number = 16;
const WALK_SPEED: number = 2.0;        // m/s 前后
const STRAFE_SPEED: number = 1.5;      // m/s 左右
const PLAYER_RADIUS: number = 0.3;     // 碰撞半径
const MOVE_DEAD_ZONE: number = 0.05;   // 摇杆死区

/** 2D 轴对齐包围盒（XZ 平面），用于碰撞。 */
export interface AABB2 {
  minX: number;
  maxX: number;
  minZ: number;
  maxZ: number;
}

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
  private updateListener: (() => void) | undefined = undefined;

  // 自由移动
  private moveInputX: number = 0;
  private moveInputY: number = 0;
  private tickTimer: number | undefined = undefined;
  private lastTickTime: number = 0;
  private boundsMin: Vec2 | undefined = undefined;
  private boundsMax: Vec2 | undefined = undefined;
  private colliders: AABB2[] = [];

  constructor(
    initial: Waypoint | undefined = undefined,
    panSensitivity: number = DEFAULT_PAN_SENSITIVITY
  ) {
    super();
    this.panSensitivity = panSensitivity;
    if (initial !== undefined) {
      this.position = { x: initial.position.x, y: initial.position.y, z: initial.position.z };
      this.currentWaypointId = initial.id;
      this.yaw = initial.yaw;
      this.pitch = initial.pitch;
    }
  }

  getCurrentWaypointId(): string {
    return this.currentWaypointId;
  }

  getPositionX(): number {
    return this.position.x;
  }

  getPositionZ(): number {
    return this.position.z;
  }

  getYaw(): number {
    return this.yaw;
  }

  setOnUpdate(callback: () => void): void {
    this.updateListener = callback;
  }

  setFocusPoint(p: Vec3): void {
    this.focusPoint = { x: p.x, y: p.y, z: p.z };
  }

  /** 设置移动可行区 AABB。null/undefined 表示不限制。 */
  setBounds(min: Vec2 | undefined, max: Vec2 | undefined): void {
    this.boundsMin = min;
    this.boundsMax = max;
  }

  /** 设置不可入障碍物列表（会替换现有）。 */
  setColliders(list: AABB2[]): void {
    this.colliders = list.slice();
  }

  /**
   * 摇杆输入。(mx, my) ∈ [-1, 1]：
   *   mx 正 = 向右 strafe
   *   my 正 = 屏幕下移（调用方）；内部取反作为"前进"
   */
  setMoveInput(mx: number, my: number): void {
    this.moveInputX = mx;
    this.moveInputY = my;
    const mag: number = Math.abs(mx) + Math.abs(my);
    if (mag > MOVE_DEAD_ZONE && this.tickTimer === undefined) {
      this.startTick();
    }
  }

  private startTick(): void {
    this.lastTickTime = Date.now();
    const step = (): void => {
      const now: number = Date.now();
      const dt: number = Math.min(0.05, (now - this.lastTickTime) / 1000);
      this.lastTickTime = now;
      this.integrateMove(dt);
      const mag: number = Math.abs(this.moveInputX) + Math.abs(this.moveInputY);
      if (mag > MOVE_DEAD_ZONE) {
        this.tickTimer = setTimeout(step, FRAME_MS);
      } else {
        this.tickTimer = undefined;
      }
    };
    step();
  }

  private integrateMove(dt: number): void {
    // 移动时取消正在播的 teleport 动画，用户立刻接管
    if (this.animTimer !== undefined) {
      this.cancelAnimation();
    }

    const sinY: number = Math.sin(this.yaw);
    const cosY: number = Math.cos(this.yaw);
    // forward_xz = (-sin yaw, -cos yaw)，right_xz = (cos yaw, -sin yaw)
    const forwardAmt: number = -this.moveInputY;          // 摇杆上 = 前进
    const strafeAmt: number = this.moveInputX;

    const vx: number = -sinY * forwardAmt * WALK_SPEED + cosY * strafeAmt * STRAFE_SPEED;
    const vz: number = -cosY * forwardAmt * WALK_SPEED - sinY * strafeAmt * STRAFE_SPEED;

    let nx: number = this.position.x + vx * dt;
    let nz: number = this.position.z + vz * dt;

    // AABB 可行区夹取
    if (this.boundsMin !== undefined) {
      nx = Math.max(this.boundsMin.x, nx);
      nz = Math.max(this.boundsMin.z, nz);
    }
    if (this.boundsMax !== undefined) {
      nx = Math.min(this.boundsMax.x, nx);
      nz = Math.min(this.boundsMax.z, nz);
    }

    // 障碍物滑动：先单独试 X 方向，再在新 X 位置上试 Z 方向
    if (this.colliders.length > 0) {
      const hitBox = (px: number, pz: number): boolean => {
        for (const c of this.colliders) {
          if (
            px + PLAYER_RADIUS > c.minX && px - PLAYER_RADIUS < c.maxX &&
            pz + PLAYER_RADIUS > c.minZ && pz - PLAYER_RADIUS < c.maxZ
          ) {
            return true;
          }
        }
        return false;
      };
      const triedX: number = hitBox(nx, this.position.z) ? this.position.x : nx;
      const triedZ: number = hitBox(triedX, nz) ? this.position.z : nz;
      nx = triedX;
      nz = triedZ;
    }

    this.position.x = nx;
    this.position.z = nz;
    this.apply();
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

    const endYaw: number = target.yaw;
    const endPitch: number = target.pitch;

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

      // 动画期间根据当前位置实时更新内部 yaw/pitch（用于小地图显示）
      const intermediateYaw: number = this.yawFromQuat(q);
      this.yaw = intermediateYaw;
      if (this.updateListener !== undefined) {
        this.updateListener();
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

  /** 从四元数反推 yaw（绕 Y 轴角度）。 */
  private yawFromQuat(q: Quat): number {
    return 2 * Math.atan2(q.y, q.w);
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

    if (this.updateListener !== undefined) {
      this.updateListener();
    }
  }
}
