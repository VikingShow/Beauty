/**
 * 根特悬案 · 线索数据
 *
 * 1432 年 Van Eyck《根特祭坛画 · 公正法官》面板被窃，至今未寻回。
 * 传说原作藏于本馆某幅画的背后。6 条线索散布在各画作中，
 * 集齐即可锁定宿主画：Antonello da Messina《男子肖像》。
 */

import { DAVID_EXHIBITS, Exhibit } from './Exhibits';

export interface Clue {
  id: string;
  hostExhibitId: string;
  orderLabel: string;
  detailText: string;
  whisper: string;
  criterion: string;
  excludes: string[];
}

export const TARGET_EXHIBIT_ID: string = 'antonello_portrait';
export const TOTAL_CLUE_COUNT: number = 6;

export const DAVID_CLUES: Clue[] = [
  {
    id: 'clue_century',
    hostExhibitId: 'uccello_san_romano',
    orderLabel: '第一声低语',
    detailText: '战场的尘土落定，长矛的阴影在地面汇成精确的网格——网格深处浮现一行古老的文字。',
    whisper: '我栖身于十五世纪的画中。哥伦布尚未起航，达芬奇还是个孩子。',
    criterion: '画作完成于 15 世纪（1400–1499）',
    excludes: [
      'mona_lisa', 'school_of_athens', 'david_napoleon',
      'bruegel_hunters', 'vermeer_pearl_earring', 'vermeer_milkmaid',
      'friedrich_wanderer', 'renoir_luncheon', 'hopper_nighthawks',
      'monet_sunrise', 'klimt_kiss', 'degas_dance', 'giorgione_tempest',
    ],
  },
  {
    id: 'clue_portrait',
    hostExhibitId: 'mona_lisa',
    orderLabel: '第二声低语',
    detailText: '蒙娜丽莎的微笑微微一颤——她没有开口，但你听见了一句话。',
    whisper: '我栖身于一幅肖像画。画中只有一人——或两人——在宁静中对视。',
    criterion: '画科为肖像画（单人/双人肖像，非群像/历史/风景）',
    excludes: [
      'botticelli_primavera', 'school_of_athens', 'david_napoleon',
      'mantegna_triumphs', 'bruegel_hunters', 'vermeer_milkmaid',
      'friedrich_wanderer', 'renoir_luncheon', 'hopper_nighthawks',
      'giorgione_tempest', 'uccello_san_romano', 'monet_sunrise',
      'klimt_kiss', 'degas_dance',
    ],
  },
  {
    id: 'clue_small',
    hostExhibitId: 'vermeer_pearl_earring',
    orderLabel: '第三声低语',
    detailText: '珍珠耳环微光一闪——那光芒突然强烈得不像是颜料。',
    whisper: '我栖身于一小幅画中。不足一臂之长，需靠得很近才能看清我的秘密。',
    criterion: '画作最长边 < 90 cm',
    excludes: [
      'botticelli_primavera', 'school_of_athens', 'david_napoleon',
      'mantegna_triumphs', 'bruegel_hunters', 'friedrich_wanderer',
      'renoir_luncheon', 'hopper_nighthawks', 'uccello_san_romano',
      'monet_sunrise', 'klimt_kiss',
    ],
  },
  {
    id: 'clue_italian',
    hostExhibitId: 'bruegel_hunters',
    orderLabel: '第四声低语',
    detailText: '雪地上呼出的白雾聚成一个词——不是佛兰芒语，不是荷兰语，不是德语。',
    whisper: '我的宿主画家来自南方。橄榄树、大理石与拉丁语的土地。',
    criterion: '画家为意大利人',
    excludes: [
      'van_eyck_arnolfini', 'bruegel_hunters', 'vermeer_pearl_earring',
      'vermeer_milkmaid', 'friedrich_wanderer', 'renoir_luncheon',
      'hopper_nighthawks', 'monet_sunrise', 'klimt_kiss', 'degas_dance',
    ],
  },
  {
    id: 'clue_island',
    hostExhibitId: 'giorgione_tempest',
    orderLabel: '第五声低语',
    detailText: '暴风雨的闪电劈开天空，照亮了远方海面上孤岛的轮廓——一座由石头与柠檬树构成的岛。',
    whisper: '我栖身于岛屿孕育的画中。不是大陆——是海中央。',
    criterion: '画家生于西西里岛',
    excludes: [
      'mona_lisa', 'botticelli_primavera', 'school_of_athens',
      'david_napoleon', 'mantegna_triumphs', 'uccello_san_romano',
    ],
  },
  {
    id: 'clue_flemish',
    hostExhibitId: 'van_eyck_arnolfini',
    orderLabel: '第六声低语',
    detailText: '凸面镜里映出访客的身影——他说了一句不属于这个时空的话。',
    whisper: '我的宿主从北方学会了用油调和颜料。在那之前，意大利人只用蛋清。',
    criterion: '画家以引入弗拉芒油画技法至意大利而著称',
    excludes: [],
  },
];

export function clueForExhibit(exhibitId: string): Clue | undefined {
  for (const c of DAVID_CLUES) {
    if (c.hostExhibitId === exhibitId) return c;
  }
  return undefined;
}

export function findClueById(id: string): Clue | undefined {
  for (const c of DAVID_CLUES) {
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
  for (const e of DAVID_EXHIBITS) {
    if (!containsId(excluded, e.id)) result.push(e.id);
  }
  return result;
}

export function isCandidate(exhibitId: string, collectedClueIds: string[]): boolean {
  const ids: string[] = candidateExhibitIds(collectedClueIds);
  return containsId(ids, exhibitId);
}
