export interface Position3 {
  x: number;
  y: number;
  z: number;
}

export interface Scale3 {
  x: number;
  y: number;
  z: number;
}

export interface Quaternion {
  x: number;
  y: number;
  z: number;
  w: number;
}

export interface PlacedArtwork {
  id: string;
  modelUri: string;
  modelName: string;
  position: Position3;
  rotation: Quaternion;
  scale: Scale3;
  nodePath: string;
  slotId: string;
}

export type SceneType = 'gltf' | '3dgs';

export interface ExhibitionLayout {
  id: string;
  name: string;
  sceneUri: string;
  sceneType: SceneType;
  placedArtworks: PlacedArtwork[];
  cameraPosition: Position3;
  cameraRotation: Quaternion;
  createdAt: number;
  updatedAt: number;
}

export interface PresetScene {
  id: string;
  name: string;
  nameZh: string;
  uri: Resource;
  type: SceneType;
  description: string;
  boundsMin?: Position3;
  boundsMax?: Position3;
}

export const PRESET_SCENES: PresetScene[] = [
  {
    id: 'white_cube',
    name: 'White Cube',
    nameZh: '白立方展厅',
    uri: $rawfile('gltf/white_cube/scene.gltf'),
    type: 'gltf',
    description: '简洁白色展厅，9个画位 + 1个雕塑位',
    boundsMin: { x: -4, y: 0, z: -4 },
    boundsMax: { x: 4, y: 0, z: 4 }
  },
  {
    id: 'salon_carre',
    name: 'Salon Carré',
    nameZh: '沙龙展厅',
    uri: $rawfile('gltf/salon_carre/scene.gltf'),
    type: 'gltf',
    description: '法式沙龙展厅，22个画位 + 1个雕塑位',
    boundsMin: { x: -9, y: 0, z: -7 },
    boundsMax: { x: 9, y: 0, z: 7 }
  },
  {
    id: 'chinese_gallery',
    name: 'Chinese Gallery',
    nameZh: '中国馆',
    uri: $rawfile('gltf/chinese_gallery/scene.gltf'),
    type: 'gltf',
    description: '中式三厅，12幅传世名画',
    boundsMin: { x: -15, y: 0, z: -10 },
    boundsMax: { x: 15, y: 0, z: 10 }
  },
  {
    id: 'david',
    name: 'David Gallery',
    nameZh: '大卫馆',
    uri: $rawfile('gltf/David/scene.gltf'),
    type: 'gltf',
    description: '文艺复兴艺术馆，18幅名画',
    boundsMin: { x: -20, y: 0, z: -15 },
    boundsMax: { x: 20, y: 0, z: 15 }
  }
];

export function generateId(): string {
  return Date.now().toString(36) + Math.random().toString(36).substring(2, 8);
}
