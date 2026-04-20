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
 * Phase 1B 测试航点：围绕原点的四个方位。
 * 正式展厅场景会在 Phase 1C 里替换。
 */
export const TEST_WAYPOINTS: Waypoint[] = [
  { id: 'front', name: '正面', position: { x: 0, y: 0, z: 5 }, yaw: 0, pitch: 0 },
  { id: 'right', name: '右侧', position: { x: 5, y: 0, z: 0 }, yaw: Math.PI / 2, pitch: 0 },
  { id: 'back', name: '背面', position: { x: 0, y: 0, z: -5 }, yaw: Math.PI, pitch: 0 },
  { id: 'left', name: '左侧', position: { x: -5, y: 0, z: 0 }, yaw: -Math.PI / 2, pitch: 0 },
  { id: 'top', name: '俯视', position: { x: 0, y: 4.2, z: 1.8 }, yaw: 0, pitch: -1.2 }
];
