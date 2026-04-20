import { Vec3 } from '../utils/Types';

/** 一个可传送观察点。 */
export interface Waypoint {
  id: string;
  name: string;
  position: Vec3;
  yaw: number;
  pitch: number;
}

/** 内墙上的一个门洞（沿 X 轴的开口）。 */
export interface Doorway {
  xStart: number;
  xEnd: number;
}

/** 一道与 X 轴平行、位于 z=z 处的内墙。 */
export interface InternalWall {
  z: number;
  doorways: Doorway[];
}

/** 房间整体布局，提供给小地图绘制。 */
export interface RoomLayout {
  worldWidth: number;
  worldDepth: number;
  internalWalls: InternalWall[];
}

/**
 * 三厅展馆布局（与 scripts/generate_gallery.py 中的常量保持一致）。
 *
 *  z=-17.5 ┌──────────────────┐  北
 *          │   北厅 (R1)      │
 *  z=-7.5  ├══◇═════════◇═════┤  ← 内墙 1（门洞 x∈[-7,-3]、[3,7]）
 *          │  中央大厅 (R2)    │
 *  z=+7.5  ├══◇═════════◇═════┤  ← 内墙 2
 *          │   南厅 (R3)      │
 *  z=+17.5 └──────────────────┘  南
 *      x=-12.5         x=+12.5
 */
export const GALLERY_LAYOUT: RoomLayout = {
  worldWidth: 25,
  worldDepth: 35,
  internalWalls: [
    {
      z: -7.5,
      doorways: [
        { xStart: -7, xEnd: -3 },
        { xStart: 3, xEnd: 7 }
      ]
    },
    {
      z: 7.5,
      doorways: [
        { xStart: -7, xEnd: -3 },
        { xStart: 3, xEnd: 7 }
      ]
    }
  ]
};

export const GALLERY_WAYPOINTS: Waypoint[] = [
  { id: 'north_hall', name: '北厅', position: { x: 0, y: 1.6, z: -12 }, yaw: 0, pitch: 0 },
  { id: 'center', name: '中央大厅', position: { x: 0, y: 1.6, z: 0 }, yaw: 0, pitch: 0 },
  { id: 'south_hall', name: '南厅', position: { x: 0, y: 1.6, z: 12 }, yaw: Math.PI, pitch: 0 },
  { id: 'center_east', name: '中厅东侧', position: { x: 9, y: 1.6, z: 0 }, yaw: -Math.PI / 2, pitch: 0 },
  { id: 'center_west', name: '中厅西侧', position: { x: -9, y: 1.6, z: 0 }, yaw: Math.PI / 2, pitch: 0 }
];
