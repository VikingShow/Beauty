/**
 * 白立方展厅 · 槽位数据
 * 由 scripts/generate_white_cube.py 自动生成，请勿手动编辑。
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

export const WHITE_CUBE_SLOTS: ParsedSlot[] = [
  { name: 'Slot_Painting_North01', slotType: 'painting', slotId: 'north01', positionX: -4.5, positionY: 1.55, positionZ: -5.0, facingX: 0, facingY: 0, facingZ: 1, maxWidth: 1.2, maxHeight: 0.9, label: '北墙左' },
  { name: 'Slot_Painting_North02', slotType: 'painting', slotId: 'north02', positionX: 0.0, positionY: 1.55, positionZ: -5.0, facingX: 0, facingY: 0, facingZ: 1, maxWidth: 1.2, maxHeight: 0.9, label: '北墙中' },
  { name: 'Slot_Painting_North03', slotType: 'painting', slotId: 'north03', positionX: 4.5, positionY: 1.55, positionZ: -5.0, facingX: 0, facingY: 0, facingZ: 1, maxWidth: 1.2, maxHeight: 0.9, label: '北墙右' },
  { name: 'Slot_Painting_South01', slotType: 'painting', slotId: 'south01', positionX: -3.0, positionY: 1.55, positionZ: 5.0, facingX: 0, facingY: 0, facingZ: -1, maxWidth: 1.2, maxHeight: 0.9, label: '南墙左' },
  { name: 'Slot_Painting_South02', slotType: 'painting', slotId: 'south02', positionX: 3.0, positionY: 1.55, positionZ: 5.0, facingX: 0, facingY: 0, facingZ: -1, maxWidth: 1.2, maxHeight: 0.9, label: '南墙右' },
  { name: 'Slot_Painting_East01', slotType: 'painting', slotId: 'east01', positionX: 7.5, positionY: 1.55, positionZ: -2.5, facingX: -1, facingY: 0, facingZ: 0, maxWidth: 1.2, maxHeight: 0.9, label: '东墙前' },
  { name: 'Slot_Painting_East02', slotType: 'painting', slotId: 'east02', positionX: 7.5, positionY: 1.55, positionZ: 2.5, facingX: -1, facingY: 0, facingZ: 0, maxWidth: 1.2, maxHeight: 0.9, label: '东墙后' },
  { name: 'Slot_Painting_West01', slotType: 'painting', slotId: 'west01', positionX: -7.5, positionY: 1.55, positionZ: -2.5, facingX: 1, facingY: 0, facingZ: 0, maxWidth: 1.2, maxHeight: 0.9, label: '西墙前' },
  { name: 'Slot_Painting_West02', slotType: 'painting', slotId: 'west02', positionX: -7.5, positionY: 1.55, positionZ: 2.5, facingX: 1, facingY: 0, facingZ: 0, maxWidth: 1.2, maxHeight: 0.9, label: '西墙后' },
  { name: 'Slot_Sculpture_Center', slotType: 'sculpture', slotId: 'center', positionX: 0.0, positionY: 0.0, positionZ: 0.0, facingX: 0, facingY: 0, facingZ: 0, maxWidth: 2.0, maxHeight: 3.0, label: '中央雕塑位' },
];
