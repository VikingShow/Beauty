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

// ==================== 大卫馆 · 根特悬案 ====================
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
    // —— David 展台（实墙大方块，高 4.87m 到屋顶）——
    // 来自 analyze_walls.py 精确几何：X=[7.02, 10.20], Z=[-3.44, +3.44]
    { id: 'david_enclosure', minX: 7.02, maxX: 10.20, minZ: -3.44, maxZ: 3.44, color: '#6f6a5aCC', solid: true, zIndex: 3 },
    // —— 中央隔断墙：X=[-0.69, -0.32] × Z=[-3.13, 3.16]，独立纵向墙 ——
    { id: 'center_divider', minX: -0.69, maxX: -0.32, minZ: -3.13, maxZ: 3.16, color: '#8a8577DD', solid: true, zIndex: 3 },
    // —— 西北通顶隔断 + 立柱（通顶 4.87m）：从西墙 X=-10 横插到 X=-6.20 的中央立柱 ——
    // 对应 walls mesh Y=±0.2 那两平面 + X=-6.25 的立柱
    { id: 'nw_partition', minX: -10.0, maxX: -6.20, minZ: -0.19, maxZ: 0.16, color: '#8a8577DD', solid: true, zIndex: 3 },
    // —— David 穹顶弧形墙延伸（基于 analyze_walls.py 精确几何）——
    // 当前 david_enclosure 仅覆盖 pedestal [Z=-3.44, +3.44]，但弧墙向南延伸至 Z≈+4.55
    { id: 'alcove_right_1', minX: 7.47, maxX: 8.79, minZ: 3.44, maxZ: 3.96, color: '#6f6a5aCC', solid: true, zIndex: 3 },
    { id: 'alcove_right_2', minX: 7.04, maxX: 8.07, minZ: 3.96, maxZ: 4.58, color: '#6f6a5aCC', solid: true, zIndex: 3 },
    { id: 'alcove_left_1', minX: 7.47, maxX: 8.79, minZ: -3.96, maxZ: -3.44, color: '#6f6a5aCC', solid: true, zIndex: 3 },
    { id: 'alcove_left_2', minX: 7.04, maxX: 8.07, minZ: -4.58, maxZ: -3.96, color: '#6f6a5aCC', solid: true, zIndex: 3 },
    // —— 19 幅策展画作（Space A/B/C 结构）：北墙 8 + 西墙 3 + 南墙 2 + 展台 E/W 2 + 中央隔断 4 ——
    // Space A · 理性与秩序（北墙西段 Leonardo 三杰 / 早期佛罗伦萨）
    { id: 'p_leonardo_last_supper', minX: -8.25, maxX: -5.75, minZ: -7.5, maxZ: -7.38, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_mona_lisa', minX: -4.78, maxX: -3.82, minZ: -7.5, maxZ: -7.38, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_school_of_athens', minX: -2.6, maxX: -0.6, minZ: -7.5, maxZ: -7.38, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_creation_of_adam', minX: 0.6, maxX: 3.0, minZ: -7.5, maxZ: -7.38, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_birth_of_venus', minX: 4.0, maxX: 6.0, minZ: -7.5, maxZ: -7.38, color: '#d4b678DD', zIndex: 5 },
    // Space B/C · 北墙东段（威尼斯 + Raphael 圣母）
    { id: 'p_venus_of_urbino', minX: 11.0, maxX: 12.6, minZ: -7.5, maxZ: -7.38, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_botticelli_primavera', minX: 13.1, maxX: 15.1, minZ: -7.5, maxZ: -7.38, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_raphael_sistine_madonna', minX: 15.48, maxX: 16.52, minZ: -7.5, maxZ: -7.38, color: '#d4b678DD', zIndex: 5 },
    // 西墙：Space A 三件（Leonardo / Masaccio / Fra Angelico）
    { id: 'p_virgin_of_the_rocks', minX: -10, maxX: -9.88, minZ: -5.49, maxZ: -4.51, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_fra_angelico_deposition', minX: -10, maxX: -9.88, minZ: -2.7, maxZ: -1.3, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_masaccio_trinity', minX: -10, maxX: -9.88, minZ: 1.475, maxZ: 2.525, color: '#d4b678DD', zIndex: 5 },
    // 南墙西段：Space B 历史题材（Mantegna / Uccello）
    { id: 'p_mantegna_triumphs', minX: -6.2, maxX: -4.8, minZ: 7.38, maxZ: 7.50, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_uccello_san_romano', minX: -3.4, maxX: -1.6, minZ: 7.38, maxZ: 7.50, color: '#d4b678DD', zIndex: 5 },
    // David 展台东面：Michelangelo《最后的审判》正对入口（2.6m 通顶垂直大画）
    { id: 'p_michelangelo_last_judgment', minX: 10.20, maxX: 10.32, minZ: -1.14, maxZ: 1.14, color: '#d4b678DD', zIndex: 6 },
    // 中央隔断东面（Space C 宗教）：Bellini + Piero
    { id: 'p_bellini_resurrection', minX: -0.32, maxX: -0.20, minZ: -2.56, maxZ: -1.44, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_piero_baptism', minX: -0.32, maxX: -0.20, minZ: 1.515, maxZ: 2.485, color: '#d4b678DD', zIndex: 5 },
    // 中央隔断西面（Space C 威尼斯 + 肖像）：Giorgione + Antonello
    { id: 'p_giorgione_tempest', minX: -0.81, maxX: -0.69, minZ: -2.535, maxZ: -1.465, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_antonello_portrait', minX: -0.81, maxX: -0.69, minZ: 1.645, maxZ: 2.355, color: '#d4b678DD', zIndex: 5 }
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

// ==================== 中国馆 · 兰亭序之谜 ====================
// 三进院落：山门(Z+1)→A厅(Z-8)→前院→B厅(Z-26)→中院→C厅(Z-44)
// A厅(南厅)17m×10m, B厅(中厅)15.1m×8.5m, C厅(北厅)13.6m×7.5m
// 游廊连接东西两侧，总纵深约50m

export const CHINESE_GALLERY_LAYOUT: RoomLayout = {
  worldWidth: 21,
  worldDepth: 55,
  worldCenterX: 0,
  worldCenterZ: -24,
  internalWalls: [],
  boundsMin: { x: -10.8, z: -49.6 },
  boundsMax: { x: 10.8, z: 2.4 },
  features: [
    // ==== 山门与入口 ====
    { id: 'gate_left_col', minX: -3.62, maxX: -3.38, minZ: 1.88, maxZ: 2.12, color: '#6b2b22CC', solid: true, zIndex: 4 },
    { id: 'gate_center_col', minX: -0.12, maxX: 0.12, minZ: 1.88, maxZ: 2.12, color: '#6b2b22CC', solid: true, zIndex: 4 },
    { id: 'gate_right_col', minX: 3.38, maxX: 3.62, minZ: 1.88, maxZ: 2.12, color: '#6b2b22CC', solid: true, zIndex: 4 },

    // ==== A厅台基与北墙画作 ====
    { id: 'hall_a_platform', minX: -4.5, maxX: 4.5, minZ: -11.25, maxZ: -4.75, color: '#9e968F88', zIndex: 1 },
    { id: 'hall_a_wall_n0', minX: -7.75, maxX: -6.55, minZ: -2.195, maxZ: -2.045, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'hall_a_wall_n1', minX: -4.975, maxX: -3.625, minZ: -2.195, maxZ: -2.045, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'hall_a_wall_n2', minX: -2.025, maxX: -0.775, minZ: -2.195, maxZ: -2.045, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'hall_a_wall_n3', minX: 0.775, maxX: 2.025, minZ: -2.195, maxZ: -2.045, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'hall_a_wall_n4', minX: 3.625, maxX: 4.975, minZ: -2.195, maxZ: -2.045, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'hall_a_wall_n5', minX: 6.55, maxX: 7.75, minZ: -2.195, maxZ: -2.045, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'p_qianli_jiangshan', minX: -10.25, maxX: -7.75, minZ: -2.03, maxZ: -2.01, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_fuchun_shanju', minX: -5.75, maxX: -4.25, minZ: -2.03, maxZ: -2.01, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_xishan_xinglv', minX: -0.35, maxX: 0.35, minZ: -2.03, maxZ: -2.01, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_xiao_xiang', minX: 3.6, maxX: 5.4, minZ: -2.03, maxZ: -2.01, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_zaochun', minX: 8.15, maxX: 8.85, minZ: -2.03, maxZ: -2.01, color: '#d4b678DD', zIndex: 5 },

    // ==== 前院游廊 ====
    { id: 'corr_west_1', minX: -8.56, maxX: -8.44, minZ: -13.25, maxZ: -10.75, color: '#5a5a3a88', solid: true, zIndex: 2 },
    { id: 'corr_east_1', minX: 8.44, maxX: 8.56, minZ: -13.25, maxZ: -10.75, color: '#5a5a3a88', solid: true, zIndex: 2 },

    // ==== B厅台基、北墙与画作 ====
    { id: 'hall_b_platform', minX: -4.0, maxX: 4.0, minZ: -28.25, maxZ: -23.75, color: '#9e968F88', zIndex: 1 },
    { id: 'hall_b_wall_n0', minX: -6.843, maxX: -5.707, minZ: -21.945, maxZ: -21.795, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'hall_b_wall_n1', minX: -4.255, maxX: -3.045, minZ: -21.945, maxZ: -21.795, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'hall_b_wall_n2', minX: -1.655, maxX: -0.645, minZ: -21.945, maxZ: -21.795, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'hall_b_wall_n3', minX: 0.645, maxX: 1.655, minZ: -21.945, maxZ: -21.795, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'hall_b_wall_n4', minX: 3.045, maxX: 4.255, minZ: -21.945, maxZ: -21.795, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'hall_b_wall_n5', minX: 5.707, maxX: 6.843, minZ: -21.945, maxZ: -21.795, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'p_luoshen_fu', minX: -8.75, maxX: -6.25, minZ: -21.78, maxZ: -21.76, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_hanxizai_yeyan', minX: -4.75, maxX: -3.25, minZ: -21.78, maxZ: -21.76, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_zanhua_shinv', minX: -0.6, maxX: 0.6, minZ: -21.78, maxZ: -21.76, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_wuniu', minX: 3.5, maxX: 4.5, minZ: -21.78, maxZ: -21.76, color: '#d4b678DD', zIndex: 5 },

    // ==== 中院游廊 ====
    { id: 'corr_west_2', minX: -8.56, maxX: -8.44, minZ: -35.25, maxZ: -32.75, color: '#5a5a3a88', solid: true, zIndex: 2 },
    { id: 'corr_east_2', minX: 8.44, maxX: 8.56, minZ: -35.25, maxZ: -32.75, color: '#5a5a3a88', solid: true, zIndex: 2 },

    // ==== C厅台基、北墙与画作 ====
    { id: 'hall_c_platform', minX: -3.75, maxX: 3.75, minZ: -46.0, maxZ: -42.0, color: '#9e968F88', zIndex: 1 },
    { id: 'hall_c_wall_n0', minX: -6.16, maxX: -5.14, minZ: -40.445, maxZ: -40.295, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'hall_c_wall_n1', minX: -3.81, maxX: -2.69, minZ: -40.445, maxZ: -40.295, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'hall_c_wall_n2', minX: -1.435, maxX: -0.565, minZ: -40.445, maxZ: -40.295, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'hall_c_wall_n3', minX: 0.565, maxX: 1.435, minZ: -40.445, maxZ: -40.295, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'hall_c_wall_n4', minX: 2.69, maxX: 3.81, minZ: -40.445, maxZ: -40.295, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'hall_c_wall_n5', minX: 5.14, maxX: 6.16, minZ: -40.445, maxZ: -40.295, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'p_lushan_gao', minX: -0.3, maxX: 0.3, minZ: -40.28, maxZ: -40.26, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_mo_putao', minX: 6.625, maxX: 6.975, minZ: -44.6, maxZ: -43.4, color: '#d4b678DD', zIndex: 5 },
    { id: 'p_bada_shanren_lotus', minX: -6.975, maxX: -6.625, minZ: -44.6, maxZ: -43.4, color: '#d4b678DD', zIndex: 5 },

    // ==== 庭院围墙（外侧连续，围合三进院落） ====
    { id: 'perim_w_s', minX: -9.1, maxX: -8.9, minZ: -2.12, maxZ: 1.5, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'perim_w_f', minX: -9.1, maxX: -8.9, minZ: -21.87, maxZ: -14.12, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'perim_w_b', minX: -9.1, maxX: -8.9, minZ: -47.87, maxZ: -30.37, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'perim_e_s', minX: 8.9, maxX: 9.1, minZ: -2.12, maxZ: 1.5, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'perim_e_f', minX: 8.9, maxX: 9.1, minZ: -21.87, maxZ: -14.12, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'perim_e_b', minX: 8.9, maxX: 9.1, minZ: -47.87, maxZ: -30.37, color: '#d9d2c7CC', solid: true, zIndex: 3 },

    // ==== 庭院连接墙 ====
    { id: 'court_w1', minX: -8.6, maxX: -8.4, minZ: -21.87, maxZ: -14.5, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'court_e1', minX: 8.4, maxX: 8.6, minZ: -21.87, maxZ: -14.5, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'court_w2', minX: -8.6, maxX: -8.4, minZ: -36.5, maxZ: -30.37, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'court_e2', minX: 8.4, maxX: 8.6, minZ: -36.5, maxZ: -30.37, color: '#d9d2c7CC', solid: true, zIndex: 3 },

    // ==== 院门柱 ====
    { id: 'gate_front_l', minX: -1.62, maxX: -1.38, minZ: -15.12, maxZ: -14.88, color: '#6b2b22CC', solid: true, zIndex: 4 },
    { id: 'gate_front_r', minX: 1.38, maxX: 1.62, minZ: -15.12, maxZ: -14.88, color: '#6b2b22CC', solid: true, zIndex: 4 },
    { id: 'gate_back_l', minX: -1.37, maxX: -1.13, minZ: -31.32, maxZ: -31.08, color: '#6b2b22CC', solid: true, zIndex: 4 },
    { id: 'gate_back_r', minX: 1.13, maxX: 1.37, minZ: -31.32, maxZ: -31.08, color: '#6b2b22CC', solid: true, zIndex: 4 },

    // ==== 山墙（东西侧全高围合，柱外侧露出） ====
    { id: 'hall_a_gable_w', minX: -8.35, maxX: -8.15, minZ: -14.12, maxZ: -2.12, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'hall_a_gable_e', minX: 8.15, maxX: 8.35, minZ: -14.12, maxZ: -2.12, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'hall_b_gable_w', minX: -7.45, maxX: -7.25, minZ: -30.37, maxZ: -21.87, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'hall_b_gable_e', minX: 7.25, maxX: 7.45, minZ: -30.37, maxZ: -21.87, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'hall_c_gable_w', minX: -6.70, maxX: -6.50, minZ: -47.87, maxZ: -40.37, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'hall_c_gable_e', minX: 6.50, maxX: 6.70, minZ: -47.87, maxZ: -40.37, color: '#d9d2c7CC', solid: true, zIndex: 3 },

    // ==== 山门翼墙（连接山门柱→围墙，X=-8.9~-3.6 / 3.6~8.9） ====
    { id: 'gate_wing_w', minX: -8.9, maxX: -3.6, minZ: 1.87, maxZ: 2.03, color: '#d9d2c7CC', solid: true, zIndex: 3 },
    { id: 'gate_wing_e', minX: 3.6, maxX: 8.9, minZ: 1.87, maxZ: 2.03, color: '#d9d2c7CC', solid: true, zIndex: 3 },

    // ==== 中院走廊柱（贴 HallB 南墙） ====
    { id: 'corr_col_w_s', minX: -8.62, maxX: -8.38, minZ: -30.62, maxZ: -30.38, color: '#7a3025CC', solid: true, zIndex: 4 },
    { id: 'corr_col_e_s', minX: 8.38, maxX: 8.62, minZ: -30.62, maxZ: -30.38, color: '#7a3025CC', solid: true, zIndex: 4 },

    // ==== 柱网（取边柱与中轴柱作关键碰撞） ====
    { id: 'hall_a_col_w_n', minX: -8.65, maxX: -8.35, minZ: -2.15, maxZ: -1.85, color: '#7a3025CC', solid: true, zIndex: 4 },
    { id: 'hall_a_col_e_n', minX: 8.35, maxX: 8.65, minZ: -2.15, maxZ: -1.85, color: '#7a3025CC', solid: true, zIndex: 4 },
    { id: 'hall_a_col_c_mid', minX: -0.15, maxX: 0.15, minZ: -8.15, maxZ: -7.85, color: '#7a3025CC', solid: true, zIndex: 4 },
    { id: 'hall_b_col_w_n', minX: -7.69, maxX: -7.41, minZ: -21.89, maxZ: -21.61, color: '#7a3025CC', solid: true, zIndex: 4 },
    { id: 'hall_b_col_e_n', minX: 7.41, maxX: 7.69, minZ: -21.89, maxZ: -21.61, color: '#7a3025CC', solid: true, zIndex: 4 },
    { id: 'hall_b_col_c_mid', minX: -0.14, maxX: 0.14, minZ: -26.14, maxZ: -25.86, color: '#7a3025CC', solid: true, zIndex: 4 },
    { id: 'hall_c_col_w_n', minX: -6.93, maxX: -6.67, minZ: -40.38, maxZ: -40.12, color: '#7a3025CC', solid: true, zIndex: 4 },
    { id: 'hall_c_col_e_n', minX: 6.67, maxX: 6.93, minZ: -40.38, maxZ: -40.12, color: '#7a3025CC', solid: true, zIndex: 4 },
    { id: 'hall_c_col_c_mid', minX: -0.13, maxX: 0.13, minZ: -44.13, maxZ: -43.87, color: '#7a3025CC', solid: true, zIndex: 4 },

    // ==== 台阶（标记，不做硬碰撞，保留通行） ====
    { id: 'hall_a_steps', minX: -0.75, maxX: 0.75, minZ: -15.837, maxZ: -14.613, color: '#9e968F66', zIndex: 1 },
    { id: 'hall_b_steps', minX: -0.75, maxX: 0.75, minZ: -31.837, maxZ: -30.613, color: '#9e968F66', zIndex: 1 },
    { id: 'hall_c_steps', minX: -0.75, maxX: 0.75, minZ: -49.338, maxZ: -48.112, color: '#9e968F66', zIndex: 1 },
  ],
};

export const CHINESE_GALLERY_WAYPOINTS: Waypoint[] = [
  { id: 'entrance', name: '山门', position: { x: 0, y: 1.65, z: 0 }, yaw: Math.PI, pitch: 0 },
  { id: 'hall_a', name: '山水之间', position: { x: 0, y: 1.65, z: -6 }, yaw: Math.PI, pitch: 0 },
  { id: 'courtyard_1', name: '前院', position: { x: 0, y: 1.65, z: -18 }, yaw: Math.PI, pitch: 0 },
  { id: 'hall_b', name: '人物与叙事', position: { x: 0, y: 1.65, z: -26 }, yaw: Math.PI, pitch: 0 },
  { id: 'courtyard_2', name: '中院', position: { x: 0, y: 1.65, z: -35 }, yaw: Math.PI, pitch: 0 },
  { id: 'hall_c', name: '文人写意', position: { x: 0, y: 1.65, z: -44 }, yaw: Math.PI, pitch: 0 },
];
