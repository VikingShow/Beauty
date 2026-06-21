/**
 * 中国馆 · 画中世界配色方案
 *
 * 每幅画的微型 3D 世界使用中国传统色系。
 * 与 WebView 的 PAINTING_WORLDS 结构一致，可直插 index.html 使用。
 */

export interface PaintingWorldTheme {
  sky: string;      // 天空/远景色
  ground: string;   // 地面色
  fog: string;      // 雾气色
  accent: string;   // 强调色（建筑/装饰）
  trees: boolean;   // 是否有树
  water: boolean;   // 是否有水面
}

export const CHINESE_PAINTING_WORLDS: Record<string, PaintingWorldTheme> = {
  qianli_jiangshan: {
    sky: '#4A7C59',
    ground: '#2D5A27',
    fog: '#8FBC8F',
    accent: '#FFD700',
    trees: true,
    water: true,
  },
  fuchun_shanju: {
    sky: '#C8D5C0',
    ground: '#8B7355',
    fog: '#B8C8B0',
    accent: '#2F2F2F',
    trees: true,
    water: true,
  },
  xishan_xinglv: {
    sky: '#D4C5A9',
    ground: '#6B5B3A',
    fog: '#A89880',
    accent: '#FFFFFF',
    trees: true,
    water: false,
  },
  xiao_xiang: {
    sky: '#B0C4DE',
    ground: '#5A7A5A',
    fog: '#87AFC0',
    accent: '#D2B48C',
    trees: true,
    water: true,
  },
  zaochun: {
    sky: '#E8D5B7',
    ground: '#8B6B4A',
    fog: '#D4C4A8',
    accent: '#90EE90',
    trees: true,
    water: false,
  },
  luoshen_fu: {
    sky: '#FFB6C1',
    ground: '#DDA0DD',
    fog: '#FFC0CB',
    accent: '#FFFFFF',
    trees: false,
    water: true,
  },
  hanxizai_yeyan: {
    sky: '#1A0A00',
    ground: '#3A1A00',
    fog: '#2A1000',
    accent: '#FFD700',
    trees: false,
    water: false,
  },
  zanhua_shinv: {
    sky: '#FFE4E1',
    ground: '#D4A574',
    fog: '#FFDAB9',
    accent: '#FF69B4',
    trees: true,
    water: false,
  },
  wuniu: {
    sky: '#87CEEB',
    ground: '#6B8E23',
    fog: '#98FB98',
    accent: '#8B4513',
    trees: true,
    water: false,
  },
  lushan_gao: {
    sky: '#4682B4',
    ground: '#2F4F2F',
    fog: '#708090',
    accent: '#FFFFFF',
    trees: true,
    water: true,
  },
  mo_putao: {
    sky: '#2F2F2F',
    ground: '#1A1A1A',
    fog: '#3A3A3A',
    accent: '#6B3FA0',
    trees: false,
    water: false,
  },
  bada_shanren_lotus: {
    sky: '#D3D3D3',
    ground: '#2F4F4F',
    fog: '#A9A9A9',
    accent: '#FFFFFF',
    trees: false,
    water: true,
  },
};
