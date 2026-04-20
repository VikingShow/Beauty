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
  /** 可选：俯视缩略图（Resource 指向 $rawfile 或 $r('app.media.xxx')）。 */
  floorplanImage?: Resource;
  /**
   * 小地图"朝上"方向对应的世界 yaw 角（弧度）。
   * 默认 0 表示 yaw=0（forward=-Z）对应小地图的上方；
   * David 场景的图片 top 对应 yaw=-π/2（forward=+X），即 -Math.PI/2。
   */
  imageNorthYawOffset?: number;
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
  { id: 'north_hall', name: '北厅', position: { x: 0, y: 2.0, z: -12 }, yaw: 0, pitch: 0 },
  { id: 'center', name: '中央大厅', position: { x: 0, y: 2.0, z: 0 }, yaw: 0, pitch: 0 },
  { id: 'south_hall', name: '南厅', position: { x: 0, y: 2.0, z: 12 }, yaw: Math.PI, pitch: 0 },
  { id: 'center_east', name: '中厅东侧', position: { x: 9, y: 2.0, z: 0 }, yaw: -Math.PI / 2, pitch: 0 },
  { id: 'center_west', name: '中厅西侧', position: { x: -9, y: 2.0, z: 0 }, yaw: Math.PI / 2, pitch: 0 }
];

/**
 * 第一关 "David" —— Art Gallery by Zeps3D (CC-BY 4.0)。
 *
 * 经 glTF 节点矩阵分析，模型在世界空间约 6m × 6m × 7m（米单位）。
 * 根节点做了 Z-up → Y-up + 缩放 0.01（cm→m）变换。
 * 航点坐标都用米。人眼视高 1.7m。
 */
export const DAVID_LAYOUT: RoomLayout = {
  // 匹配俯视图纵横比 0.613。图片 top 对应世界 -X 方向（朝向 David 深处）。
  worldWidth: 5,
  worldDepth: 8.2,
  internalWalls: [],
  floorplanImage: $rawfile('gltf/David/floorplan.png'),
  imageNorthYawOffset: Math.PI / 2
};

/**
 * 航点约定（与图对齐）：
 *  - 入口 = 图片下方 = 世界 +X（从 +X 侧进门）
 *  - 雕像/深处 = 图片上方 = 世界 -X
 *  - 东侧 = 图片右侧 = 世界 -Z
 *  - 西侧 = 图片左侧 = 世界 +Z
 *
 * 默认 yaw 都是 +π/2（面向 -X，向图片上方看/朝 David 走）。
 */
export const DAVID_WAYPOINTS: Waypoint[] = [
  { id: 'entrance', name: '入口', position: { x: 2.5, y: 1.7, z: 0 }, yaw: Math.PI / 2, pitch: 0 },
  { id: 'center', name: '中央', position: { x: 0, y: 1.7, z: 0 }, yaw: Math.PI / 2, pitch: 0 },
  { id: 'statue', name: '雕像', position: { x: -1.5, y: 1.7, z: 0 }, yaw: Math.PI / 2, pitch: 0 },
  { id: 'east', name: '东侧', position: { x: 0, y: 1.7, z: -1.5 }, yaw: Math.PI / 2, pitch: 0 },
  { id: 'west', name: '西侧', position: { x: 0, y: 1.7, z: 1.5 }, yaw: Math.PI / 2, pitch: 0 }
];
