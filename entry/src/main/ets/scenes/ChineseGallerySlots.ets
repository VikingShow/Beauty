/**
 * 中国馆 · 槽位数据
 * 由 Blender 场景导出，与 gltf/chinese_gallery/scene.gltf 中的 Empty 节点同步。
 */

export type SlotType = 'painting' | 'sculpture' | 'spawn';

export interface ParsedSlot {
  name: string;
  slotType: SlotType;
  slotId: string;
  positionX: number;
  positionY: number;
  positionZ: number;
  facingX: number;
  facingY: number;
  facingZ: number;
  maxWidth: number;
  maxHeight: number;
  label: string;
}

export const CHINESE_GALLERY_SLOTS: ParsedSlot[] = [
  // ===== 厅 A · 山水之间 (北墙, facing +Z) =====
  { name: 'Slot_Painting_N01', slotType: 'painting', slotId: 'qianli_jiangshan', positionX: -9.0, positionY: 1.8, positionZ: -2.02, facingX: 0, facingY: 0, facingZ: 1, maxWidth: 2.5, maxHeight: 0.5, label: '千里江山图' },
  { name: 'Slot_Painting_N02', slotType: 'painting', slotId: 'fuchun_shanju', positionX: -5.0, positionY: 1.8, positionZ: -2.02, facingX: 0, facingY: 0, facingZ: 1, maxWidth: 1.5, maxHeight: 0.3, label: '富春山居图' },
  { name: 'Slot_Painting_N03', slotType: 'painting', slotId: 'xishan_xinglv', positionX: 0.0, positionY: 2.4, positionZ: -2.02, facingX: 0, facingY: 0, facingZ: 1, maxWidth: 0.7, maxHeight: 1.1, label: '溪山行旅图' },
  { name: 'Slot_Painting_N04', slotType: 'painting', slotId: 'xiao_xiang', positionX: 4.5, positionY: 1.8, positionZ: -2.02, facingX: 0, facingY: 0, facingZ: 1, maxWidth: 1.8, maxHeight: 0.65, label: '潇湘图' },
  { name: 'Slot_Painting_N05', slotType: 'painting', slotId: 'zaochun', positionX: 8.5, positionY: 2.2, positionZ: -2.02, facingX: 0, facingY: 0, facingZ: 1, maxWidth: 0.7, maxHeight: 0.95, label: '早春图' },

  // ===== 厅 B · 人物与叙事 (北墙, facing +Z) =====
  { name: 'Slot_Painting_N06', slotType: 'painting', slotId: 'luoshen_fu', positionX: -7.5, positionY: 1.75, positionZ: -21.77, facingX: 0, facingY: 0, facingZ: 1, maxWidth: 2.5, maxHeight: 0.5, label: '洛神赋图' },
  { name: 'Slot_Painting_N07', slotType: 'painting', slotId: 'hanxizai_yeyan', positionX: -4.0, positionY: 1.75, positionZ: -21.77, facingX: 0, facingY: 0, facingZ: 1, maxWidth: 1.5, maxHeight: 0.3, label: '韩熙载夜宴图' },
  { name: 'Slot_Painting_N08', slotType: 'painting', slotId: 'zanhua_shinv', positionX: 0.0, positionY: 1.75, positionZ: -21.77, facingX: 0, facingY: 0, facingZ: 1, maxWidth: 1.2, maxHeight: 0.45, label: '簪花仕女图' },
  { name: 'Slot_Painting_N09', slotType: 'painting', slotId: 'wuniu', positionX: 4.0, positionY: 1.75, positionZ: -21.77, facingX: 0, facingY: 0, facingZ: 1, maxWidth: 1.0, maxHeight: 0.25, label: '五牛图' },

  // ===== 厅 C · 文人写意 (北墙+东墙+西墙) =====
  { name: 'Slot_Painting_N10', slotType: 'painting', slotId: 'lushan_gao', positionX: 0.0, positionY: 2.2, positionZ: -40.27, facingX: 0, facingY: 0, facingZ: 1, maxWidth: 0.6, maxHeight: 1.15, label: '庐山高图' },
  { name: 'Slot_Painting_N11', slotType: 'painting', slotId: 'mo_putao', positionX: 6.8, positionY: 1.9, positionZ: -44.0, facingX: -1, facingY: 0, facingZ: 0, maxWidth: 0.35, maxHeight: 0.9, label: '墨葡萄图' },
  { name: 'Slot_Painting_N12', slotType: 'painting', slotId: 'bada_shanren_lotus', positionX: -6.8, positionY: 1.9, positionZ: -44.0, facingX: 1, facingY: 0, facingZ: 0, maxWidth: 0.4, maxHeight: 0.85, label: '荷花水鸟图' },

  // 入口
  { name: 'Slot_Spawn', slotType: 'spawn', slotId: 'spawn', positionX: 0.0, positionY: 1.65, positionZ: 1.0, facingX: 0, facingY: 0, facingZ: -1, maxWidth: 0, maxHeight: 0, label: '入口' },
];
