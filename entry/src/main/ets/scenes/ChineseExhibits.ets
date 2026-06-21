/**
 * 中国馆 · 12 幅传世名画的展品元数据。
 * 坐标基于 glTF 场景中画作面板的三维位置。
 */

export type Facing = '+X' | '-X' | '+Z' | '-Z';

export interface Exhibit {
  id: string;
  titleZh: string;
  titleEn: string;
  artist: string;
  year: string;
  sizeCm: string;
  school: string;
  description: string;
  anchorX: number;
  anchorZ: number;
  facing: Facing;
}

export const CHINESE_EXHIBITS: Exhibit[] = [
  // ========= 厅 A · 山水之间（南厅，最先进入）=========
  // 5幅画在北墙 (Z≈-2.02)，面南 (+Z)
  {
    id: 'qianli_jiangshan',
    titleZh: '千里江山图',
    titleEn: 'A Thousand Li of Rivers and Mountains',
    artist: '王希孟', year: '1113', sizeCm: '51.5 × 1191.5 cm',
    school: '北宋 · 青绿山水',
    description: '十八岁的王希孟在宋徽宗指导下完成此卷。青绿重彩铺展千里江山，渔村野市、水榭亭台错落其间，是中国青绿山水的巅峰之作。',
    anchorX: -9.0, anchorZ: -2.02, facing: '+Z',
  },
  {
    id: 'fuchun_shanju',
    titleZh: '富春山居图',
    titleEn: 'Dwelling in the Fuchun Mountains',
    artist: '黄公望', year: '1350', sizeCm: '33 × 636.9 cm',
    school: '元代 · 文人山水',
    description: '黄公望晚年隐居富春江畔，以枯笔淡墨绘此长卷。山峦起伏、江水平远，笔墨极简而气象万千。此画曾遭火劫断为两截，分藏两岸。',
    anchorX: -5.0, anchorZ: -2.02, facing: '+Z',
  },
  {
    id: 'xishan_xinglv',
    titleZh: '溪山行旅图',
    titleEn: 'Travelers Among Mountains and Streams',
    artist: '范宽', year: '约 1000', sizeCm: '206.3 × 103.3 cm',
    school: '北宋 · 北派山水',
    description: '巨碑式构图的终极形态。主峰占据画面三分之二，山脚商旅渺小如蚁。范宽以雨点皴营造出山石的坚实重量感——人在自然面前，唯有敬畏。',
    anchorX: 0.0, anchorZ: -2.02, facing: '+Z',
  },
  {
    id: 'xiao_xiang',
    titleZh: '潇湘图',
    titleEn: 'Xiao and Xiang Rivers',
    artist: '董源', year: '约 950', sizeCm: '50 × 141.4 cm',
    school: '五代 · 南派山水',
    description: '江南水乡的平远法则。董源以披麻皴写丘陵起伏，不画山的骨骼，只画山的呼吸。董其昌跋"此卷最为得意"——南宗山水的源头在此。',
    anchorX: 4.5, anchorZ: -2.02, facing: '+Z',
  },
  {
    id: 'zaochun',
    titleZh: '早春图',
    titleEn: 'Early Spring',
    artist: '郭熙', year: '1072', sizeCm: '158.3 × 108.1 cm',
    school: '北宋 · 院体山水',
    description: '郭熙提出"三远法"（高远、深远、平远），此画即为教科书。早春雾气中，山峦从近处推向远方，每一层都是一个空间世界。',
    anchorX: 8.5, anchorZ: -2.02, facing: '+Z',
  },

  // ========= 厅 B · 人物与叙事（中厅）=========
  // 4幅画在北墙 (Z≈-21.77)，面南 (+Z)
  {
    id: 'luoshen_fu',
    titleZh: '洛神赋图',
    titleEn: 'Nymph of the Luo River',
    artist: '顾恺之', year: '约 380', sizeCm: '27.1 × 572.8 cm',
    school: '东晋 · 人物画',
    description: '曹植《洛神赋》的视觉转译。洛神凌波微步，衣带当风，与曹植隔水相望。顾恺之的"高古游丝描"如春蚕吐丝——中国人物画的第一座高峰。',
    anchorX: -7.5, anchorZ: -21.77, facing: '+Z',
  },
  {
    id: 'hanxizai_yeyan',
    titleZh: '韩熙载夜宴图',
    titleEn: 'Night Revels of Han Xizai',
    artist: '顾闳中', year: '约 970', sizeCm: '28.7 × 335.5 cm',
    school: '五代 · 工笔人物',
    description: '南唐后主李煜派顾闳中潜入韩熙载府邸，目识心记画下这场夜宴。五段连环画式叙事，听琴、观舞、休憩、清吹、送别——一场被监视的夜宴。',
    anchorX: -4.0, anchorZ: -21.77, facing: '+Z',
  },
  {
    id: 'zanhua_shinv',
    titleZh: '簪花仕女图',
    titleEn: 'Court Ladies Adorned with Flowers',
    artist: '周昉', year: '约 780', sizeCm: '46 × 180 cm',
    school: '唐代 · 绮罗人物',
    description: '五位盛唐贵妇在庭院中拈花、弄犬、执扇、徐行。衣裙薄如蝉翼，体态丰腴雍容——这是大唐气度的容颜。周昉"周家样"影响远及日本。',
    anchorX: 0.0, anchorZ: -21.77, facing: '+Z',
  },
  {
    id: 'wuniu',
    titleZh: '五牛图',
    titleEn: 'Five Oxen',
    artist: '韩滉', year: '约 780', sizeCm: '20.8 × 139.8 cm',
    school: '唐代 · 畜兽画',
    description: '五头牛从左到右一字排开，各具姿态。韩滉以朴拙的线条画出牛的筋骨与温厚——泥土与汗水的味道穿透绢本而来。',
    anchorX: 4.0, anchorZ: -21.77, facing: '+Z',
  },

  // ========= 厅 C · 文人写意（北厅）=========
  // 北墙1幅 + 东墙1幅 + 西墙1幅
  {
    id: 'lushan_gao',
    titleZh: '庐山高图',
    titleEn: 'Lofty Mount Lu',
    artist: '沈周', year: '1467', sizeCm: '193.8 × 98.1 cm',
    school: '明代 · 吴门画派',
    description: '沈周为老师陈宽祝寿而作，以庐山之巍峨喻师德之高。融合王蒙的繁密与董巨的温润——吴门画派的开山巨制。',
    anchorX: 0.0, anchorZ: -40.27, facing: '+Z',
  },
  {
    id: 'mo_putao',
    titleZh: '墨葡萄图',
    titleEn: 'Ink Grapes',
    artist: '徐渭', year: '约 1580', sizeCm: '165.7 × 64.5 cm',
    school: '明代 · 泼墨大写意',
    description: '一株野葡萄在狂风骤雨中倾泻而出。墨汁淋漓，不见勾勒，只有泼洒与挥扫。徐渭自题"笔底明珠无处卖"——这就是压抑到极致后的爆发。',
    anchorX: 6.8, anchorZ: -44.0, facing: '-X',
  },
  {
    id: 'bada_shanren_lotus',
    titleZh: '荷花水鸟图',
    titleEn: 'Lotus and Waterfowl',
    artist: '八大山人', year: '约 1690', sizeCm: '165 × 76 cm',
    school: '清初 · 遗民画',
    description: '一枝残荷、一块怪石、一只白眼向天的水鸟。八大山人以极简笔墨写亡国之痛——翻白眼的鸟是中国美术史上最孤独的凝视。',
    anchorX: -6.8, anchorZ: -44.0, facing: '+X',
  },
];

const ACTIVATION_RADIUS: number = 2.5;

interface FacingXZ { x: number; z: number; }

function facingVec(f: Facing): FacingXZ {
  if (f === '+X') return { x: 1, z: 0 };
  if (f === '-X') return { x: -1, z: 0 };
  if (f === '+Z') return { x: 0, z: 1 };
  return { x: 0, z: -1 };
}

export function nearestChineseExhibitId(playerX: number, playerZ: number): string {
  let bestId: string = '';
  let bestDist2: number = ACTIVATION_RADIUS * ACTIVATION_RADIUS;
  for (const e of CHINESE_EXHIBITS) {
    const dx: number = playerX - e.anchorX;
    const dz: number = playerZ - e.anchorZ;
    const d2: number = dx * dx + dz * dz;
    if (d2 >= bestDist2) continue;
    const f: FacingXZ = facingVec(e.facing);
    if (dx * f.x + dz * f.z <= 0) continue;
    bestDist2 = d2;
    bestId = e.id;
  }
  return bestId;
}

export function findChineseExhibit(id: string): Exhibit | undefined {
  for (const e of CHINESE_EXHIBITS) {
    if (e.id === id) return e;
  }
  return undefined;
}
