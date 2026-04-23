/**
 * 根特悬案 · 线索数据
 *
 * 1934 年 Van Eyck《根特祭坛画 · 公正法官》被窃，至今未寻回。
 * 传说原作被藏于本馆某幅画板的背后。6 条线索散布在其他画作中，
 * 集齐即可唯一锁定宿主画（Fra Angelico《基督下十字架》· 1432）。
 */

export interface Clue {
  id: string;              // 'clue_year', 'clue_facing', ...
  hostExhibitId: string;   // 该线索"附身"在哪幅画里（玩家走近它时触发）
  orderLabel: string;      // '第一声低语' / '第二声低语' ...
  detailText: string;      // 观察模态里的"发现"叙述
  whisper: string;         // 线索本体（画中人的一句窃语）
}

export const TARGET_EXHIBIT_ID: string = 'fra_angelico_deposition';
export const TOTAL_CLUE_COUNT: number = 6;

export const DAVID_CLUES: Clue[] = [
  {
    id: 'clue_year',
    hostExhibitId: 'leonardo_last_supper',
    orderLabel: '第一声低语',
    detailText: '午夜钟声将酒杯的倒影震出一丝涟漪，杯底浮现一行极细的字。',
    whisper: '我的年岁，比这桌上的晚餐年长六十余载。',
  },
  {
    id: 'clue_facing',
    hostExhibitId: 'bellini_resurrection',
    orderLabel: '第二声低语',
    detailText: '基督复活的晨光里，你仿佛听见一缕低微的呼吸。',
    whisper: '我面朝晨光升起的方向。',
  },
  {
    id: 'clue_mother',
    hostExhibitId: 'raphael_sistine_madonna',
    orderLabel: '第三声低语',
    detailText: '圣母怀中的圣婴忽然望向你，嘴角微微一动。',
    whisper: '我的宿主画中，也有一位母亲的眼泪。',
  },
  {
    id: 'clue_panel',
    hostExhibitId: 'masaccio_trinity',
    orderLabel: '第四声低语',
    detailText: '凹陷的礼拜堂墙壁深处，传来一声木板的轻叩。',
    whisper: '我非壁画——我栖身于木板之上。',
  },
  {
    id: 'clue_nude',
    hostExhibitId: 'venus_of_urbino',
    orderLabel: '第五声低语',
    detailText: '维纳斯在床榻上望向你，轻声说出一句不属于她的话。',
    whisper: '我的宿主画家，此生从未绘过一具裸体。',
  },
  {
    id: 'clue_friar',
    hostExhibitId: 'school_of_athens',
    orderLabel: '第六声低语',
    detailText: '哲学家的长袍随风微动，一道身影从廊柱之后静静现身。',
    whisper: '我的宿主画家，身披黑白修道服。',
  },
];

/** 给定画的 id，返回附着其上的线索（若有）。 */
export function clueForExhibit(exhibitId: string): Clue | undefined {
  for (const c of DAVID_CLUES) {
    if (c.hostExhibitId === exhibitId) return c;
  }
  return undefined;
}

/** 按 id 查找线索。 */
export function findClueById(id: string): Clue | undefined {
  for (const c of DAVID_CLUES) {
    if (c.id === id) return c;
  }
  return undefined;
}

/** 判断某线索是否已被收集（在传入的已收集列表中）。 */
export function isCollected(clueId: string, collected: string[]): boolean {
  for (const id of collected) {
    if (id === clueId) return true;
  }
  return false;
}
