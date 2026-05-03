/**
 * 墙面射线检测器
 * 从相机 forward 方向投射射线，检测与墙面的交点，判断是否可放置画作。
 */
import { Vec3 } from '../utils/Types';

/** 墙面定义 */
export interface WallPlane {
  normal: Vec3;       // 指向房间内部的法线
  pointOnPlane: Vec3; // 面上一点
  rangeMin: number;   // 墙面第一轴最小坐标（北/南墙=X，东/西墙=Z）
  rangeMax: number;   // 墙面第一轴最大坐标
  label: string;      // 显示名
  sceneId: string;    // 所属场景
}

/** 射线与墙面相交结果 */
export interface WallHit {
  worldX: number;
  worldY: number;
  worldZ: number;
  wallNormalX: number;
  wallNormalY: number;
  wallNormalZ: number;
  wallLabel: string;
  distance: number;
  valid: boolean;
  reason: string;
}

const MAX_PLACEMENT_RANGE = 5.0;     // 最远放置距离
const MIN_PAINTING_Y = 0.5;
const MAX_PAINTING_Y = 4.5;
const MIN_SPACING = 0.3;             // 画作间最小间距（米）

/** 白立方墙面数据 */
export const WHITE_CUBE_WALLS: WallPlane[] = [
  {
    normal: { x: 0, y: 0, z: 1 },
    pointOnPlane: { x: 0, y: 0, z: -5.0 },
    rangeMin: -7.5, rangeMax: 7.5,
    label: '北墙', sceneId: 'white_cube'
  },
  {
    normal: { x: 0, y: 0, z: -1 },
    pointOnPlane: { x: 0, y: 0, z: 5.0 },
    rangeMin: -7.5, rangeMax: 7.5,
    label: '南墙', sceneId: 'white_cube'
  },
  {
    normal: { x: -1, y: 0, z: 0 },
    pointOnPlane: { x: 7.5, y: 0, z: 0 },
    rangeMin: -5.0, rangeMax: 5.0,
    label: '东墙', sceneId: 'white_cube'
  },
  {
    normal: { x: 1, y: 0, z: 0 },
    pointOnPlane: { x: -7.5, y: 0, z: 0 },
    rangeMin: -5.0, rangeMax: 5.0,
    label: '西墙', sceneId: 'white_cube'
  }
];

/** Salon Carré 墙面数据 */
export const SALON_CARRE_WALLS: WallPlane[] = [
  {
    normal: { x: 0, y: 0, z: 1 },
    pointOnPlane: { x: 0, y: 0, z: -5.0 },
    rangeMin: -15.0, rangeMax: 15.0,
    label: '北墙', sceneId: 'salon_carre'
  },
  {
    normal: { x: 0, y: 0, z: -1 },
    pointOnPlane: { x: 0, y: 0, z: 5.0 },
    rangeMin: -15.0, rangeMax: 15.0,
    label: '南墙', sceneId: 'salon_carre'
  },
  {
    normal: { x: -1, y: 0, z: 0 },
    pointOnPlane: { x: 15.0, y: 0, z: 0 },
    rangeMin: -5.0, rangeMax: 5.0,
    label: '东墙', sceneId: 'salon_carre'
  },
  {
    normal: { x: 1, y: 0, z: 0 },
    pointOnPlane: { x: -15.0, y: 0, z: 0 },
    rangeMin: -5.0, rangeMax: 5.0,
    label: '西墙', sceneId: 'salon_carre'
  }
];

/** 已放置的画作（用于碰撞检测） */
export interface PlacedArtwork {
  worldX: number;
  worldY: number;
  worldZ: number;
  width: number;
  height: number;
}

function dot3(ax: number, ay: number, az: number,
              bx: number, by: number, bz: number): number {
  return ax * bx + ay * by + az * bz;
}

function clamp(val: number, lo: number, hi: number): number {
  return val < lo ? lo : (val > hi ? hi : val);
}

/**
 * 检测射线与墙面的交点。
 * @param camPos 相机位置
 * @param camDir 相机视线方向（归一化向量）
 * @param walls 可用墙面列表
 * @param placed 已放置的画作列表
 * @param maxRange 最大检测距离
 */
export function detectWallHit(
  camX: number, camY: number, camZ: number,
  dirX: number, dirY: number, dirZ: number,
  walls: WallPlane[],
  placed: PlacedArtwork[],
  maxRange: number
): WallHit | undefined {
  let bestHit: WallHit | undefined = undefined;
  let bestDist: number = maxRange > 0 ? maxRange : MAX_PLACEMENT_RANGE;

  for (const w of walls) {
    const denom: number = dot3(dirX, dirY, dirZ, w.normal.x, w.normal.y, w.normal.z);
    // 射线必须朝向墙面（点积为负表示朝向法线反方向即朝向墙面内部）
    if (denom >= -0.001) continue;

    const numer: number = dot3(
      w.pointOnPlane.x - camX,
      w.pointOnPlane.y - camY,
      w.pointOnPlane.z - camZ,
      w.normal.x, w.normal.y, w.normal.z
    );
    const t: number = numer / denom;
    if (t <= 0.01 || t >= bestDist) continue;

    // 交点
    const hx: number = camX + dirX * t;
    const hy: number = camY + dirY * t;
    const hz: number = camZ + dirZ * t;

    // 验证 Y 在有效绘画高度内
    if (hy < MIN_PAINTING_Y || hy > MAX_PAINTING_Y) continue;

    // 验证沿墙坐标在范围内
    // 对于北/南墙（法线方向 ±Z），沿墙坐标 = X
    // 对于东/西墙（法线方向 ±X），沿墙坐标 = Z
    let alongWall: number = 0;
    if (w.normal.z !== 0) {
      alongWall = hx;  // 北/南墙，沿 X 方向
    } else {
      alongWall = hz;  // 东/西墙，沿 Z 方向
    }
    if (alongWall < w.rangeMin || alongWall > w.rangeMax) continue;

    // 检测与已放置画作的重叠
    let overlaps: boolean = false;
    for (const p of placed) {
      const dx: number = hx - p.worldX;
      const dy: number = hy - p.worldY;
      const dz: number = hz - p.worldZ;
      const dist2: number = dx * dx + dy * dy + dz * dz;
      const minDist: number = Math.max(p.width / 2, p.height / 2) + MIN_SPACING;
      if (dist2 < minDist * minDist) {
        overlaps = true;
        break;
      }
    }

    const hit: WallHit = {
      worldX: hx, worldY: hy, worldZ: hz,
      wallNormalX: w.normal.x,
      wallNormalY: w.normal.y,
      wallNormalZ: w.normal.z,
      wallLabel: w.label,
      distance: t,
      valid: !overlaps,
      reason: overlaps ? '与已有画作重叠' : ''
    };

    if (t < bestDist) {
      bestDist = t;
      bestHit = hit;
    }
  }
  return bestHit;
}

/**
 * 获取指定场景的墙面列表。
 */
export function getWallsForScene(sceneId: string): WallPlane[] {
  if (sceneId === 'salon_carre') {
    return SALON_CARRE_WALLS;
  }
  return WHITE_CUBE_WALLS;
}
