/**
 * David 场景 18 幅画作的展品元数据。
 *
 * 每条 id 对应 scene.gltf 里 painting_<id> 节点 + Minimap 里 p_<id> feature。
 * 距离检测用 anchorX / anchorZ 作为"画的中心点"（忽略画框厚度偏移）。
 * facing 表示画作正面朝向（+X/-X/+Z/-Z），用于判断玩家是否"正面看向"画。
 */

export type Facing = '+X' | '-X' | '+Z' | '-Z';

export interface Exhibit {
  id: string;
  titleZh: string;
  titleEn: string;
  artist: string;
  year: string;
  sizeCm: string;     // 原作尺寸
  school: string;     // 流派 / 空间分组
  description: string; // 两三句导览
  anchorX: number;
  anchorZ: number;
  facing: Facing;
}

export const DAVID_EXHIBITS: Exhibit[] = [
  // ========= Space A · 理性与秩序 =========
  {
    id: 'leonardo_last_supper',
    titleZh: '最后的晚餐',
    titleEn: 'The Last Supper',
    artist: 'Leonardo da Vinci',
    year: '1495–1498',
    sizeCm: '460 × 880 cm',
    school: '盛期文艺复兴 · 米兰',
    description: '耶稣宣布有人将背叛他的那一刻。十二门徒分为四组，情绪在透视消失点的基督身上收束，单点透视把整个晚餐厅"拉进"了画里。',
    anchorX: -7.0, anchorZ: -7.5, facing: '+Z',
  },
  {
    id: 'mona_lisa',
    titleZh: '蒙娜丽莎',
    titleEn: 'Mona Lisa',
    artist: 'Leonardo da Vinci',
    year: '1503–1519',
    sizeCm: '77 × 53 cm',
    school: '盛期文艺复兴 · 佛罗伦萨',
    description: '用晕染法（sfumato）调和皮肤与空气的边界，背景是带有地质年代感的幻想山水。是人物心理与自然秩序的静默对话。',
    anchorX: -4.3, anchorZ: -7.5, facing: '+Z',
  },
  {
    id: 'virgin_of_the_rocks',
    titleZh: '岩间圣母',
    titleEn: 'Virgin of the Rocks',
    artist: 'Leonardo da Vinci',
    year: '1483–1486',
    sizeCm: '199 × 122 cm',
    school: '盛期文艺复兴 · 米兰',
    description: '圣母、圣婴、施洗约翰与天使组成金字塔构图，背景是达芬奇潜心研究的岩石、植物与光雾。宗教场景罕见地让位于自然。',
    anchorX: -10.0, anchorZ: -5.0, facing: '+X',
  },
  {
    id: 'masaccio_trinity',
    titleZh: '圣三位一体',
    titleEn: 'Holy Trinity',
    artist: 'Masaccio',
    year: '1425–1428',
    sizeCm: '667 × 317 cm',
    school: '早期文艺复兴 · 佛罗伦萨',
    description: '西方美术史上第一次系统使用数学透视的壁画。观者仿佛真的望进一座凹陷的礼拜堂，拱顶与地面在同一消失点处汇合。',
    anchorX: -10.0, anchorZ: 2.0, facing: '+X',
  },
  {
    id: 'fra_angelico_deposition',
    titleZh: '基督下十字架',
    titleEn: 'Deposition of Christ',
    artist: 'Fra Angelico',
    year: '1432',
    sizeCm: '176 × 185 cm',
    school: '早期文艺复兴 · 佛罗伦萨',
    description: '圣三一祭坛画。用晨光般的粉白调渲染神圣悲伤。金色背景被真实的托斯卡纳山景取代，宗教图像开始与当地世界共享空间。',
    anchorX: -10.0, anchorZ: -2.0, facing: '+X',
  },

  // ========= Space B · 变化与冲突 =========
  {
    id: 'birth_of_venus',
    titleZh: '维纳斯的诞生',
    titleEn: 'The Birth of Venus',
    artist: 'Sandro Botticelli',
    year: 'c.1485',
    sizeCm: '172.5 × 278.5 cm',
    school: '早期文艺复兴 · 佛罗伦萨',
    description: '美之女神从贝壳上升起，身体被风神吹送向海岸。线条优先于体积，古典神话首次成为与宗教题材平起平坐的主题。',
    anchorX: 5.0, anchorZ: -7.5, facing: '+Z',
  },
  {
    id: 'botticelli_primavera',
    titleZh: '春',
    titleEn: 'Primavera',
    artist: 'Sandro Botticelli',
    year: 'c.1480',
    sizeCm: '203 × 314 cm',
    school: '早期文艺复兴 · 佛罗伦萨',
    description: '维纳斯、三女神、墨丘利、花神在橙树林里组成缓慢的舞步。500 多种植物被精准描绘，神话是哲学与诗的合奏。',
    anchorX: 14.1, anchorZ: -7.5, facing: '+Z',
  },
  {
    id: 'venus_of_urbino',
    titleZh: '乌尔比诺的维纳斯',
    titleEn: 'Venus of Urbino',
    artist: 'Titian',
    year: '1538',
    sizeCm: '119 × 165 cm',
    school: '威尼斯画派',
    description: '女神走下神坛，变成一位在自家卧室里与观者对视的女性。威尼斯的光与色把古典躯体温暖成肉身。',
    anchorX: 11.8, anchorZ: -7.5, facing: '+Z',
  },
  {
    id: 'mantegna_triumphs',
    titleZh: '凯撒的凯旋',
    titleEn: 'Triumphs of Caesar',
    artist: 'Andrea Mantegna',
    year: '1484–1492',
    sizeCm: '266 × 278 cm（每幅）',
    school: '早期文艺复兴 · 帕多瓦',
    description: '九幅巨幅组画还原古罗马凯撒游行。曼特尼亚用近乎考古学的严谨重建旗帜、战利品与乐师，古典世界第一次被"完整看见"。',
    anchorX: -5.5, anchorZ: 7.5, facing: '-Z',
  },
  {
    id: 'uccello_san_romano',
    titleZh: '圣罗马诺之战',
    titleEn: 'The Battle of San Romano',
    artist: 'Paolo Uccello',
    year: 'c.1438–1440',
    sizeCm: '182 × 323 cm',
    school: '早期文艺复兴 · 佛罗伦萨',
    description: '倒地的长矛在地面上精确汇聚于一点——这是一场几何学家画的战争。战马、铠甲、身体全被透视切割成可量化的立方体。',
    anchorX: -2.5, anchorZ: 7.5, facing: '-Z',
  },

  // ========= Space C · 沉浸与观念 =========
  {
    id: 'school_of_athens',
    titleZh: '雅典学院',
    titleEn: 'The School of Athens',
    artist: 'Raphael',
    year: '1509–1511',
    sizeCm: '500 × 770 cm',
    school: '盛期文艺复兴 · 罗马',
    description: '古希腊哲学家们在一座幻想建筑中聚集。柏拉图指向理念的天空，亚里士多德指向经验的大地——整个西方思想史被定格为一次会议。',
    anchorX: -1.6, anchorZ: -7.5, facing: '+Z',
  },
  {
    id: 'creation_of_adam',
    titleZh: '创造亚当',
    titleEn: 'The Creation of Adam',
    artist: 'Michelangelo',
    year: '1508–1512',
    sizeCm: '280 × 570 cm（局部）',
    school: '盛期文艺复兴 · 罗马',
    description: '西斯廷礼拜堂天顶画最著名的片段。上帝与亚当即将相触的两根手指之间，留出了西方美术史上最有名的一厘米空隙。',
    anchorX: 1.8, anchorZ: -7.5, facing: '+Z',
  },
  {
    id: 'raphael_sistine_madonna',
    titleZh: '西斯廷圣母',
    titleEn: 'Sistine Madonna',
    artist: 'Raphael',
    year: '1513–1514',
    sizeCm: '265 × 196 cm',
    school: '盛期文艺复兴 · 罗马',
    description: '圣母抱着圣婴从云端向观者走来。画面下方两位凭栏的小天使已经脱离了原作成为独立的流行文化符号。',
    anchorX: 16.0, anchorZ: -7.5, facing: '+Z',
  },
  {
    id: 'michelangelo_last_judgment',
    titleZh: '最后的审判',
    titleEn: 'The Last Judgment',
    artist: 'Michelangelo',
    year: '1536–1541',
    sizeCm: '1370 × 1200 cm',
    school: '盛期文艺复兴 · 罗马',
    description: '西斯廷礼拜堂祭坛背后的末日巨作。近四百具裸体灵魂被安放在基督审判的漩涡中，宗教情感被推向肉身的极致。',
    anchorX: 10.2, anchorZ: 0.0, facing: '+X',
  },
  {
    id: 'bellini_resurrection',
    titleZh: '基督复活',
    titleEn: 'Resurrection of Christ',
    artist: 'Giovanni Bellini',
    year: '1475–1479',
    sizeCm: '148 × 128 cm',
    school: '威尼斯画派',
    description: '黎明的薄雾中，基督从石棺上悄然升起。贝利尼让威尼斯潟湖的蓝灰色晨光成为神迹发生的时间坐标。',
    anchorX: -0.32, anchorZ: -2.0, facing: '+X',
  },
  {
    id: 'piero_baptism',
    titleZh: '基督受洗',
    titleEn: 'The Baptism of Christ',
    artist: 'Piero della Francesca',
    year: 'c.1450',
    sizeCm: '167 × 116 cm',
    school: '早期文艺复兴 · 桑塞波尔克罗',
    description: '树、鸽子、人物都被安置在严格的几何骨架上。Piero 是数学家也是画家，他画出的静默有着几何证明般的不可动摇。',
    anchorX: -0.32, anchorZ: 2.0, facing: '+X',
  },
  {
    id: 'giorgione_tempest',
    titleZh: '暴风雨',
    titleEn: 'The Tempest',
    artist: 'Giorgione',
    year: 'c.1508',
    sizeCm: '82 × 73 cm',
    school: '威尼斯画派',
    description: '士兵、喂奶的女人、远方的闪电——至今没人能确定这张画的主题。乔尔乔内把"画的意义"第一次让渡给了观者的想象。',
    anchorX: -0.69, anchorZ: -2.0, facing: '-X',
  },
  {
    id: 'antonello_portrait',
    titleZh: '男子肖像',
    titleEn: 'Portrait of a Man',
    artist: 'Antonello da Messina',
    year: 'c.1475',
    sizeCm: '25 × 35 cm',
    school: '早期文艺复兴 · 西西里',
    description: '三分之二侧脸、油画光泽、微微上扬的嘴角——Antonello 把北方尼德兰的油画技法带进意大利，"个体性"从此成为肖像画的主题。',
    anchorX: -0.69, anchorZ: 2.0, facing: '-X',
  },
];

/** 快速按 id 查找。 */
export function findExhibit(id: string): Exhibit | undefined {
  for (const e of DAVID_EXHIBITS) {
    if (e.id === id) return e;
  }
  return undefined;
}

/** 画作触发半径：XZ 平面距离 < 2.5m 触发。 */
const ACTIVATION_RADIUS: number = 2.5;

interface FacingXZ {
  x: number;
  z: number;
}

/** 画作正面朝向向量（指向观者）。 */
function facingVec(f: Facing): FacingXZ {
  if (f === '+X') {
    const v: FacingXZ = { x: 1, z: 0 };
    return v;
  }
  if (f === '-X') {
    const v: FacingXZ = { x: -1, z: 0 };
    return v;
  }
  if (f === '+Z') {
    const v: FacingXZ = { x: 0, z: 1 };
    return v;
  }
  const v: FacingXZ = { x: 0, z: -1 };
  return v;
}

/**
 * 返回玩家当前应激活的画作 id。
 * 判定：画作在玩家 XZ 半径 ACTIVATION_RADIUS 内，且玩家位于画作的正面侧（点积 > 0）。
 * 多个候选时取最近。
 */
export function nearestExhibitId(
  playerX: number, playerZ: number
): string {
  let bestId: string = '';
  let bestDist2: number = ACTIVATION_RADIUS * ACTIVATION_RADIUS;
  for (const e of DAVID_EXHIBITS) {
    const dx: number = playerX - e.anchorX;
    const dz: number = playerZ - e.anchorZ;
    const d2: number = dx * dx + dz * dz;
    if (d2 >= bestDist2) continue;
    // 玩家必须在画的正面侧：(player - anchor) · facing > 0
    const f: FacingXZ = facingVec(e.facing);
    if (dx * f.x + dz * f.z <= 0) continue;
    bestDist2 = d2;
    bestId = e.id;
  }
  return bestId;
}
