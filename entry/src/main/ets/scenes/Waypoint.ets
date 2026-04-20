import { Vec3 } from '../utils/Types';

/** 一个可传送观察点。 */
export interface Waypoint {
  id: string;
  name: string;
  position: Vec3;
  yaw: number;
  pitch: number;
}

/**
 * 圆形画廊（VR Round Art Gallery，半径约 5.3m）的 5 个观察点。
 * Y 轴向上，约 1.6m 视高。每个航点朝不同方向（看不同的墙）。
 */
export const GALLERY_WAYPOINTS: Waypoint[] = [
  // 中心位置，朝向北墙（-Z 方向）
  { id: 'center', name: '中心', position: { x: 0, y: 1.6, z: 0 }, yaw: 0, pitch: 0 },
  // 靠近东墙（+X），看向东墙
  { id: 'east', name: '东厅', position: { x: 2.5, y: 1.6, z: 0 }, yaw: -Math.PI / 2, pitch: 0 },
  // 靠近北墙（-Z），看向北墙
  { id: 'north', name: '北厅', position: { x: 0, y: 1.6, z: -2.5 }, yaw: 0, pitch: 0 },
  // 靠近西墙（-X），看向西墙
  { id: 'west', name: '西厅', position: { x: -2.5, y: 1.6, z: 0 }, yaw: Math.PI / 2, pitch: 0 },
  // 靠近南墙（+Z），看向南墙
  { id: 'south', name: '南厅', position: { x: 0, y: 1.6, z: 2.5 }, yaw: Math.PI, pitch: 0 }
];
