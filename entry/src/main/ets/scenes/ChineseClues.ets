/**
 * 兰亭序之谜 · 线索数据
 *
 * 王羲之《兰亭序》真迹据传随唐太宗葬入昭陵，永绝于世。
 * 但近年有学者考证，太宗可能以摹本代葬，真迹被藏于某幅古画的夹层中。
 * 6 条线索散布在 12 幅中国画里，集齐即可唯一锁定宿主画（董源《潇湘图》）。
 */

import { CHINESE_EXHIBITS, Exhibit } from './ChineseExhibits';

export interface Clue {
  id: string;
  hostExhibitId: string;
  orderLabel: string;
  detailText: string;
  whisper: string;
  criterion: string;
  excludes: string[];
}

export const TARGET_EXHIBIT_ID: string = 'xiao_xiang';
export const TOTAL_CLUE_COUNT: number = 6;

export const CHINESE_CLUES: Clue[] = [
  {
    id: 'clue_dynasty',
    hostExhibitId: 'qianli_jiangshan',
    orderLabel: '第一声墨语',
    detailText: '青绿山水的重彩深处，仿佛有一丝若有若无的墨香透出。',
    whisper: '我所栖身之画，成于宋室南渡之前。靖康之变未起，汴京犹是天下之中。',
    criterion: '画作完成于 1127 年（北宋灭亡）之前',
    excludes: [
      'fuchun_shanju', 'hanxizai_yeyan', 'lushan_gao',
      'mo_putao', 'bada_shanren_lotus',
    ],
  },
  {
    id: 'clue_landscape',
    hostExhibitId: 'xishan_xinglv',
    orderLabel: '第二声墨语',
    detailText: '巨碑般的山体压迫而来，却在石缝间透出一线天光——那道光里藏着一行小字。',
    whisper: '我栖身于山水之间。不是人物，不是花鸟，不是畜兽。是山，是水，是云。',
    criterion: '画科为山水画（排除人物/花鸟/畜兽）',
    excludes: [
      'luoshen_fu', 'hanxizai_yeyan', 'zanhua_shinv', 'wuniu',
      'mo_putao', 'bada_shanren_lotus',
    ],
  },
  {
    id: 'clue_horizontal',
    hostExhibitId: 'luoshen_fu',
    orderLabel: '第三声墨语',
    detailText: '洛神的衣带拂过画卷，飘向一个遥远的方向。',
    whisper: '我栖身于横卷之上。长达数尺，需缓缓展开，非立轴可观。',
    criterion: '形制为手卷（横 > 100 cm，排除立轴）',
    excludes: [
      'xishan_xinglv', 'zaochun', 'zanhua_shinv',
      'lushan_gao', 'mo_putao', 'bada_shanren_lotus',
    ],
  },
  {
    id: 'clue_southern',
    hostExhibitId: 'zanhua_shinv',
    orderLabel: '第四声墨语',
    detailText: '簪花仕女的团扇之上，飘落一片江南的柳絮。',
    whisper: '我的宿主画家，一生未曾踏足汴京。他在江南，画江南。',
    criterion: '画家活跃于南方（南派/江南画派）',
    excludes: [
      'qianli_jiangshan', 'xishan_xinglv', 'luoshen_fu',
      'hanxizai_yeyan', 'zanhua_shinv', 'zaochun',
    ],
  },
  {
    id: 'clue_pima',
    hostExhibitId: 'fuchun_shanju',
    orderLabel: '第五声墨语',
    detailText: '黄公望的枯笔在纸上轻擦而过，那些干燥的墨痕忽然聚成一行文字。',
    whisper: '我的宿主画家以披麻皴名世。不是斧劈、不是卷云、不是雨点——是如麻丝般披散下来的线。',
    criterion: '画家以披麻皴为主要技法',
    excludes: [
      'qianli_jiangshan', 'xishan_xinglv', 'zaochun',
      'luoshen_fu', 'hanxizai_yeyan', 'zanhua_shinv',
      'wuniu', 'lushan_gao', 'mo_putao', 'bada_shanren_lotus',
    ],
  },
  {
    id: 'clue_nan_tang',
    hostExhibitId: 'hanxizai_yeyan',
    orderLabel: '第六声墨语',
    detailText: '夜宴散场，宾客离去，空旷的厅堂里只剩一人的脚步声。',
    whisper: '我栖身于一位南唐旧臣的画中。画成之后，南唐国灭，而画存于宋。',
    criterion: '画家为五代南唐旧臣（生活于南唐且入宋）',
    excludes: [
      'qianli_jiangshan', 'xishan_xinglv', 'fuchun_shanju',
      'luoshen_fu', 'zanhua_shinv', 'wuniu',
      'zaochun', 'lushan_gao', 'mo_putao', 'bada_shanren_lotus',
    ],
  },
];

export function clueForExhibit(exhibitId: string): Clue | undefined {
  for (const c of CHINESE_CLUES) {
    if (c.hostExhibitId === exhibitId) return c;
  }
  return undefined;
}

export function findClueById(id: string): Clue | undefined {
  for (const c of CHINESE_CLUES) {
    if (c.id === id) return c;
  }
  return undefined;
}

export function isCollected(clueId: string, collected: string[]): boolean {
  for (const id of collected) {
    if (id === clueId) return true;
  }
  return false;
}

function containsId(arr: string[], id: string): boolean {
  for (const x of arr) {
    if (x === id) return true;
  }
  return false;
}

export function candidateExhibitIds(collectedClueIds: string[]): string[] {
  const excluded: string[] = [];
  for (const clueId of collectedClueIds) {
    const c: Clue | undefined = findClueById(clueId);
    if (c === undefined) continue;
    for (const id of c.excludes) {
      if (!containsId(excluded, id)) excluded.push(id);
    }
  }
  const result: string[] = [];
  for (const e of CHINESE_EXHIBITS) {
    if (!containsId(excluded, e.id)) result.push(e.id);
  }
  return result;
}

export function isCandidate(exhibitId: string, collectedClueIds: string[]): boolean {
  const ids: string[] = candidateExhibitIds(collectedClueIds);
  return containsId(ids, exhibitId);
}
