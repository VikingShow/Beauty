import { Vec3 } from '../utils/Types';

/** 一个可传送观察点。 */
export interface Waypoint {
  id: string;
  name: string;
  position: Vec3;
  yaw: number;
  pitch: number;
}

/** 内墙上的一个门洞。 */
export interface Doorway {
  xStart: number;
  xEnd: number;
}

/** 一道与 X 轴平行、位于 z=z 处的内墙。 */
export interface InternalWall {
  z: number;
  doorways: Doorway[];
}

/** 小地图上的一个矩形元素（展品、基座、门、楼梯等）。 */
export interface SceneFeature {
  id: string;
  minX: number;
  maxX: number;
  minZ: number;
  maxZ: number;
  /** 填充颜色（支持 RGBA 透明）。 */
  color: string;
  /** 是否是实心障碍（阻挡玩家移动）。未设视为 false。 */
  solid?: boolean;
  /** 绘制层级，大的在上。 */
  zIndex?: number;
}

/** 水平面 2D 向量。 */
export interface Vec2 {
  x: number;
  z: number;
}

/** 房间整体布局，提供给小地图绘制和碰撞检测。 */
export interface RoomLayout {
  /** 小地图 X 方向（水平）覆盖的世界范围（米）。 */
  worldWidth: number;
  /** 小地图 Y 方向（垂直）覆盖的世界范围（米）。 */
  worldDepth: number;
  /** 可选：小地图中心对应的世界坐标（当模型原点不在几何中心时使用）。 */
  worldCenterX?: number;
  worldCenterZ?: number;
  /** 内墙（Z 轴平行），仅 θ=0 的场景使用；David 场景留空。 */
  internalWalls: InternalWall[];
  /** 可选：俯视缩略图；给出后 Minimap 把它当背景，features 仍会画在上方。 */
  floorplanImage?: Resource;
  /** 图片/地图上方对应的世界 yaw 值。默认 0（对应 yaw=0, forward=−Z）。 */
  imageNorthYawOffset?: number;
  /** 展品/障碍物矩形数组，用来画小地图和碰撞。 */
  features?: SceneFeature[];
  /** 玩家可行区的最小 / 最大 XZ（AABB）。未设则不限制。 */
  boundsMin?: Vec2;
  boundsMax?: Vec2;
}

// ==================== Gallery 场景（白盒展厅） ====================

export const GALLERY_LAYOUT: RoomLayout = {
  worldWidth: 25,
  worldDepth: 35,
  internalWalls: [
    { z: -7.5, doorways: [{ xStart: -7, xEnd: -3 }, { xStart: 3, xEnd: 7 }] },
    { z: 7.5, doorways: [{ xStart: -7, xEnd: -3 }, { xStart: 3, xEnd: 7 }] }
  ],
  boundsMin: { x: -12.3, z: -17.3 },
  boundsMax: { x: 12.3, z: 17.3 }
};

export const GALLERY_WAYPOINTS: Waypoint[] = [
  { id: 'north_hall', name: '北厅', position: { x: 0, y: 2.0, z: -12 }, yaw: 0, pitch: 0 },
  { id: 'center', name: '中央大厅', position: { x: 0, y: 2.0, z: 0 }, yaw: 0, pitch: 0 },
  { id: 'south_hall', name: '南厅', position: { x: 0, y: 2.0, z: 12 }, yaw: Math.PI, pitch: 0 },
  { id: 'center_east', name: '中厅东侧', position: { x: 9, y: 2.0, z: 0 }, yaw: -Math.PI / 2, pitch: 0 },
  { id: 'center_west', name: '中厅西侧', position: { x: -9, y: 2.0, z: 0 }, yaw: Math.PI / 2, pitch: 0 }
];

// ==================== 第一关 David 场景 ====================
// 数据来自 scripts/parse_david.py 从 glTF 节点矩阵解析出的世界坐标
// 模型 X 范围 −10 ~ +20.5，Z 范围 ±7.5，地板顶面 Y ≈ −0.06，视高 1.65

export const DAVID_LAYOUT: RoomLayout = {
  worldWidth: 15.5,
  worldDepth: 31,
  worldCenterX: 5.25,
  worldCenterZ: 0,
  internalWalls: [],
  imageNorthYawOffset: Math.PI / 2,
  boundsMin: { x: -9.5, z: -7 },
  boundsMax: { x: 20, z: 7 },
  features: [
    // —— 场景地面/遮挡物（不是墙）——
    { id: 'stairs', minX: 10.0, maxX: 13.6, minZ: -7.4, maxZ: 7.4, color: '#1c1c2688', zIndex: 1 },
    { id: 'tree', minX: 12.5, maxX: 18.7, minZ: -2.6, maxZ: 3.1, color: '#5a6a5099', solid: true, zIndex: 2 },
    { id: 'window', minX: 20.35, maxX: 20.55, minZ: -7.3, maxZ: 7.3, color: '#9eb4d0AA', zIndex: 4 },
    { id: 'doors', minX: 3.6, maxX: 17.3, minZ: 7.35, maxZ: 7.55, color: '#d4b67899', zIndex: 4 },
    // —— 中央展位区南北两道分隔墙（高 2.19m，挡视野；从 walls mesh Y=±3.73 解析）——
    // 北分隔：从西墙留出 3.8m 通道，到 X=18.5 之间是连续矮墙
    { id: 'partition_north', minX: -6.19, maxX: 18.51, minZ: -3.79, maxZ: -3.67, color: '#a89c84BB', solid: true, zIndex: 2 },
    // 南分隔：同上对称
    { id: 'partition_south', minX: -6.19, maxX: 18.51, minZ: 3.67, maxZ: 3.79, color: '#a89c84BB', solid: true, zIndex: 2 },
    // —— David 展台（实墙大方块，高 4.87m 到屋顶）——
    // 来自 analyze_walls.py 精确几何：X=[7.02, 10.20], Z=[-3.44, +3.44]
    { id: 'david_enclosure', minX: 7.02, maxX: 10.20, minZ: -3.44, maxZ: 3.44, color: '#6f6a5aCC', solid: true, zIndex: 3 },
    // —— 中央隔断墙：X=[-0.69, -0.32] × Z=[-3.13, 3.16]，独立纵向墙 ——
    { id: 'center_divider', minX: -0.69, maxX: -0.32, minZ: -3.13, maxZ: 3.16, color: '#8a8577DD', solid: true, zIndex: 3 },
    // —— 18 幅画：北墙 8 + 西墙 4 + 南墙 2 + 中央隔断 4（展台外不挂画，避开雕像视野）——
    // 北墙西段：三杰 + 盛期序曲
    { id: 'p_leonardo_last_supper', minX: -8.2, maxX: -5.8, minZ: -7.5, maxZ: -7.38, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_raphael_sistine_madonna', minX: -4.52, maxX: -3.48, minZ: -7.5, maxZ: -7.38, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_school_of_athens', minX: -2.0, maxX: 0.0, minZ: -7.5, maxZ: -7.38, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_creation_of_adam', minX: 1.0, maxX: 3.0, minZ: -7.5, maxZ: -7.38, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_mona_lisa', minX: 4.585, maxX: 5.415, minZ: -7.5, maxZ: -7.38, color: '#d4b678DD', zIndex: 5 },
    // 北墙东段：威尼斯画派（避开 David 展台 X=10.20 东侧 0.3m）
    { id: 'p_venus_of_urbino', minX: 10.6, maxX: 12.4, minZ: -7.5, maxZ: -7.38, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_wedding_at_cana', minX: 12.7, maxX: 14.7, minZ: -7.5, maxZ: -7.38, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_tintoretto_last_supper', minX: 14.9, maxX: 16.7, minZ: -7.5, maxZ: -7.38, color: '#d4b678DD', zIndex: 5 },
    // 西墙：早期佛罗伦萨 + 尼德兰 + Leonardo 添补
    { id: 'p_birth_of_venus', minX: -10, maxX: -9.88, minZ: -5.0, maxZ: -3.0, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_botticelli_primavera', minX: -10, maxX: -9.88, minZ: -1.0, maxZ: 1.0, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_virgin_of_the_rocks', minX: -10, maxX: -9.88, minZ: 2.01, maxZ: 2.99, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_arnolfini_portrait', minX: -10, maxX: -9.88, minZ: 3.635, maxZ: 4.365, color: '#d4b678DD', zIndex: 5 },
    // 中央隔断东面：北方文艺复兴肖像
    { id: 'p_durer_self_portrait', minX: -0.32, maxX: -0.20, minZ: -2.365, maxZ: -1.635, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_holbein_ambassadors', minX: -0.32, maxX: -0.20, minZ: 1.35, maxZ: 2.65, color: '#d4b678DD', zIndex: 5 },
    // 中央隔断西面：尼德兰风景叙事
    { id: 'p_bruegel_hunters', minX: -0.81, maxX: -0.69, minZ: -2.9, maxZ: -1.1, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_bruegel_tower', minX: -0.81, maxX: -0.69, minZ: 1.1, maxZ: 2.9, color: '#d4b678DD', zIndex: 5 },
    // 南墙西段（入口左侧、门洞 X=3.6 之前）：Michelangelo + Raphael 遗作
    { id: 'p_doni_tondo', minX: -2.6, maxX: -1.4, minZ: 7.38, maxZ: 7.50, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_raphael_transfiguration', minX: 0.32, maxX: 1.68, minZ: 7.38, maxZ: 7.50, color: '#d4b678DD', zIndex: 5 }
  ]
};

/**
 * 航点位置（使用真实世界坐标）。Y=1.65 是地板 +1.7 人眼高度。
 * 默认 yaw=−π/2 → forward=+X，朝 David/树雕方向看（图片上方是 −X，所以大部分航点会"望向图片下方"）。
 */
export const DAVID_WAYPOINTS: Waypoint[] = [
  // 入口：刚进门，站在南墙内侧，看向画廊内部
  { id: 'entrance', name: '入口', position: { x: 12, y: 1.65, z: 5.5 }, yaw: 0, pitch: 0 },
  // 雕像前：站在 David 西侧 3m 处
  { id: 'statue', name: '雕像', position: { x: 5, y: 1.65, z: 0 }, yaw: -Math.PI / 2, pitch: 0 },
  // 树雕前：站在树雕西侧 1.5m 处
  { id: 'tree', name: '树雕', position: { x: 11, y: 1.65, z: 0 }, yaw: -Math.PI / 2, pitch: 0 },
  // 西厅座椅区
  { id: 'west_lounge', name: '西厅', position: { x: -5, y: 1.65, z: 0 }, yaw: -Math.PI / 2, pitch: 0 },
  // 东窗景
  { id: 'east_window', name: '东窗', position: { x: 18, y: 1.65, z: 0 }, yaw: -Math.PI / 2, pitch: 0 }
];
