/**
 * 槽位解析器：管理场景槽位和艺术品放置状态。
 *
 * - 预设场景：直接使用预生成的槽位数据（如 WhiteCubeSlots.ets）
 * - 用户场景：运行时解析 glTF JSON 中的 Slot_* 节点（Phase 2）
 */
import { ParsedSlot, SlotType, WHITE_CUBE_SLOTS } from './WhiteCubeSlots';
import { SALON_CARRE_SLOTS } from './SalonCarreSlots';

/** 屏幕投影结果 */
export interface ScreenPoint {
  x: number;
  y: number;
  visible: boolean;
}

/** 一个已放置的艺术品 */
export interface Placement {
  slotId: string;
  artworkId: string;
  artworkTitle: string;
  scale: number;
  offsetX: number;
  offsetY: number;
  worldX?: number;
  worldY?: number;
  worldZ?: number;
}

/** 可选的艺术品条目 */
export interface ArtworkEntry {
  id: string;
  titleZh: string;
  titleEn: string;
  artist: string;
  imageUri: string;
  type: string;  // 'painting' | 'sculpture'
}

/** 一些预置的经典艺术品（公共领域，Wikimedia Commons） */
export const PRESET_ARTWORKS: ArtworkEntry[] = [
  {
    id: 'mona_lisa',
    titleZh: '蒙娜丽莎',
    titleEn: 'Mona Lisa',
    artist: 'Leonardo da Vinci',
    imageUri: 'gltf/David/paintings/mona_lisa.jpg',
    type: 'painting'
  },
  {
    id: 'starry_night',
    titleZh: '星月夜',
    titleEn: 'The Starry Night',
    artist: 'Vincent van Gogh',
    imageUri: 'gltf/David/paintings/birth_of_venus.jpg',
    type: 'painting'
  },
  {
    id: 'birth_of_venus',
    titleZh: '维纳斯的诞生',
    titleEn: 'The Birth of Venus',
    artist: 'Sandro Botticelli',
    imageUri: 'gltf/David/paintings/birth_of_venus.jpg',
    type: 'painting'
  },
  {
    id: 'school_of_athens',
    titleZh: '雅典学院',
    titleEn: 'The School of Athens',
    artist: 'Raphael',
    imageUri: 'gltf/David/paintings/school_of_athens.jpg',
    type: 'painting'
  },
  {
    id: 'creation_of_adam',
    titleZh: '创造亚当',
    titleEn: 'The Creation of Adam',
    artist: 'Michelangelo',
    imageUri: 'gltf/David/paintings/creation_of_adam.jpg',
    type: 'painting'
  },
  {
    id: 'primavera',
    titleZh: '春',
    titleEn: 'Primavera',
    artist: 'Sandro Botticelli',
    imageUri: 'gltf/David/paintings/botticelli_primavera.jpg',
    type: 'painting'
  }
];

/**
 * 获取预设场景的槽位列表。
 * 未来扩展：传入 sceneId 获取不同场景的槽位。
 */
/** 场景条目元数据 */
export interface SceneEntry {
  id: string;
  name: string;
  description: string;
  gltfPath: string;  // $rawfile path
}

export const PRESET_SCENES: SceneEntry[] = [
  {
    id: 'white_cube',
    name: 'MoMA 白立方',
    description: '15×10m 现代白立方画廊，纯白墙面 + 轨道灯',
    gltfPath: 'gltf/white_cube/scene.gltf'
  },
  {
    id: 'salon_carre',
    name: 'Salon Carré 卢浮宫方厅',
    description: '30×10m 古典方厅，深红墙面 + 筒形拱顶',
    gltfPath: 'gltf/salon_carre/scene.gltf'
  }
];

export function getPresetSlots(sceneId: string): ParsedSlot[] {
  if (sceneId === 'white_cube') {
    return WHITE_CUBE_SLOTS;
  }
  if (sceneId === 'salon_carre') {
    return SALON_CARRE_SLOTS;
  }
  return [];
}

/**
 * 从槽位列表中获取画作槽位（仅供绘画使用）。
 */
export function getPaintingSlots(slots: ParsedSlot[]): ParsedSlot[] {
  const result: ParsedSlot[] = [];
  for (const s of slots) {
    if (s.slotType === 'painting') {
      result.push(s);
    }
  }
  return result;
}

/**
 * 从槽位列表中获取雕塑槽位。
 */
export function getSculptureSlots(slots: ParsedSlot[]): ParsedSlot[] {
  const result: ParsedSlot[] = [];
  for (const s of slots) {
    if (s.slotType === 'sculpture') {
      result.push(s);
    }
  }
  return result;
}

/**
 * 从槽位列表中获取出生点。
 */
export function getSpawnSlot(slots: ParsedSlot[]): ParsedSlot | undefined {
  for (const s of slots) {
    if (s.slotType === 'spawn') {
      return s;
    }
  }
  return undefined;
}

/**
 * 将 3D 世界坐标投影到屏幕 2D 坐标。
 * 简化版：基于相机参数做透视投影。
 */
export function projectToScreen(
  worldX: number, worldY: number, worldZ: number,
  camPosX: number, camPosY: number, camPosZ: number,
  camYaw: number, camPitch: number,
  screenWidth: number, screenHeight: number,
  fovY: number
): ScreenPoint {
  const dx = worldX - camPosX;
  const dy = worldY - camPosY;
  const dz = worldZ - camPosZ;

  const cosY = Math.cos(-camYaw);
  const sinY = Math.sin(-camYaw);
  const cosP = Math.cos(-camPitch);
  const sinP = Math.sin(-camPitch);

  const rx = dx * cosY - dz * sinY;
  const rz = dx * sinY + dz * cosY;
  const ry = dy * cosP - rz * sinP;
  const rz2 = dy * sinP + rz * cosP;

  if (rz2 <= 0.01) {
    const hidden: ScreenPoint = { x: 0, y: 0, visible: false };
    return hidden;
  }

  const aspect = screenWidth / screenHeight;
  const halfH = Math.tan(fovY / 2);
  const halfW = halfH * aspect;

  const sx = (rx / rz2) / halfW;
  const sy = -(ry / rz2) / halfH;

  const screenX = (sx + 1) / 2 * screenWidth;
  const screenY = (sy + 1) / 2 * screenHeight;

  const result: ScreenPoint = {
    x: screenX,
    y: screenY,
    visible: sx > -1.2 && sx < 1.2 && sy > -1.2 && sy < 1.2
  };
  return result;
}
