/**
 * 大卫馆 18 幅画作元数据 — 与 scene.gltf 中的 painting_node_* 一一对应。
 * 全部为非宗教、非裸露题材，可过审。
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

export const DAVID_EXHIBITS: Exhibit[] = [
  // === Space A · 文艺复兴意大利 ===
  {
    id: 'mona_lisa',
    titleZh: '蒙娜丽莎',
    titleEn: 'Mona Lisa',
    artist: 'Leonardo da Vinci',
    year: '1503–1519',
    sizeCm: '77 × 53 cm',
    school: '盛期文艺复兴 · 佛罗伦萨',
    description: '晕染法调和了皮肤与空气的边界。她微笑的秘密已被追问五个世纪——她在看谁？没有人知道。',
    anchorX: -7.0, anchorZ: -7.5, facing: '+Z',
  },
  {
    id: 'botticelli_primavera',
    titleZh: '春',
    titleEn: 'Primavera',
    artist: 'Sandro Botticelli',
    year: 'c.1480',
    sizeCm: '203 × 314 cm',
    school: '早期文艺复兴 · 佛罗伦萨',
    description: '维纳斯、三女神、墨丘利在橙树林里组成缓慢的舞步。五百种植物被精准描绘，神话与自然在此合奏。',
    anchorX: -4.3, anchorZ: -7.5, facing: '+Z',
  },
  {
    id: 'school_of_athens',
    titleZh: '雅典学院',
    titleEn: 'The School of Athens',
    artist: 'Raphael',
    year: '1509–1511',
    sizeCm: '500 × 770 cm',
    school: '盛期文艺复兴 · 罗马',
    description: '柏拉图指向天空，亚里士多德指向大地。西方思想史被定格为一次会议——哲学家的群像从未如此宏大。',
    anchorX: -1.6, anchorZ: -7.5, facing: '+Z',
  },
  {
    id: 'david_napoleon',
    titleZh: '拿破仑穿越阿尔卑斯山',
    titleEn: 'Napoleon Crossing the Alps',
    artist: 'Jacques-Louis David',
    year: '1801',
    sizeCm: '261 × 221 cm',
    school: '法国新古典主义',
    description: '拿破仑骑在前蹄腾空的烈马上，披风被狂风卷起。现实中他骑的是一头骡子——但画布上，他是汉尼拔。',
    anchorX: 1.8, anchorZ: -7.5, facing: '+Z',
  },
  {
    id: 'mantegna_triumphs',
    titleZh: '凯撒的凯旋',
    titleEn: 'Triumphs of Caesar',
    artist: 'Andrea Mantegna',
    year: '1484–1492',
    sizeCm: '266 × 278 cm（每幅）',
    school: '早期文艺复兴 · 帕多瓦',
    description: '九幅巨幅组画还原古罗马凯旋游行。曼特尼亚以考古学的严谨重建旗帜、战利品与乐师——古典世界第一次被完整看见。',
    anchorX: 5.0, anchorZ: -7.5, facing: '+Z',
  },

  // === Space B · 北方文艺复兴与荷兰黄金时代 ===
  {
    id: 'van_eyck_arnolfini',
    titleZh: '阿诺芬尼夫妇像',
    titleEn: 'The Arnolfini Portrait',
    artist: 'Jan van Eyck',
    year: '1434',
    sizeCm: '82.2 × 60 cm',
    school: '早期尼德兰画派',
    description: '凸面镜暴露了房间里的所有人——包括画家本人。上方签名"范艾克曾在此"——西美史上最迷人的双人肖像。',
    anchorX: 14.1, anchorZ: -7.5, facing: '+Z',
  },
  {
    id: 'bruegel_hunters',
    titleZh: '雪中猎人',
    titleEn: 'Hunters in the Snow',
    artist: 'Pieter Bruegel the Elder',
    year: '1565',
    sizeCm: '117 × 162 cm',
    school: '佛兰德斯文艺复兴',
    description: '猎人与狗群从雪坡归来，远处溜冰的人群小如蚂蚁。勃鲁盖尔把整个村庄的冬天装进一幅画——空气冷得仿佛能呵出白雾。',
    anchorX: 16.0, anchorZ: -7.5, facing: '+Z',
  },
  {
    id: 'vermeer_pearl_earring',
    titleZh: '戴珍珠耳环的少女',
    titleEn: 'Girl with a Pearl Earring',
    artist: 'Johannes Vermeer',
    year: 'c.1665',
    sizeCm: '44.5 × 39 cm',
    school: '荷兰黄金时代',
    description: '她回过头来，嘴唇微启，珍珠在颈侧发出湿润的光。维米尔只画了三十多幅画，每一幅都是光与寂静的炼金术。',
    anchorX: 10.2, anchorZ: 0.0, facing: '+X',
  },
  {
    id: 'vermeer_milkmaid',
    titleZh: '倒牛奶的女仆',
    titleEn: 'The Milkmaid',
    artist: 'Johannes Vermeer',
    year: 'c.1658',
    sizeCm: '45.5 × 41 cm',
    school: '荷兰黄金时代',
    description: '晨光从左侧窗射入，照亮女仆专注的脸和手中的牛奶。面包上的每一粒碎屑都被精确描绘——日常劳作获得了神圣的重量。',
    anchorX: -5.5, anchorZ: 7.5, facing: '-Z',
  },

  // === Space C · 浪漫主义与现代 ===
  {
    id: 'friedrich_wanderer',
    titleZh: '雾海上的旅人',
    titleEn: 'Wanderer above the Sea of Fog',
    artist: 'Caspar David Friedrich',
    year: '1818',
    sizeCm: '94.8 × 74.8 cm',
    school: '德国浪漫主义',
    description: '一个男子背对观者站在山巅，脚下是翻涌的云海。弗里德里希说：画家不该画眼前的风景，而该画心中的风景。',
    anchorX: -2.5, anchorZ: 7.5, facing: '-Z',
  },
  {
    id: 'antonello_portrait',
    titleZh: '男子肖像',
    titleEn: 'Portrait of a Man',
    artist: 'Antonello da Messina',
    year: 'c.1475',
    sizeCm: '25 × 35 cm',
    school: '早期文艺复兴 · 西西里',
    description: '三分之二侧脸、油画光泽、微微上扬的嘴角。他把北方尼德兰的油画技法带进意大利——个体性从此成为肖像画的主题。',
    anchorX: -0.69, anchorZ: 2.0, facing: '-X',
  },
  {
    id: 'renoir_luncheon',
    titleZh: '船上的午宴',
    titleEn: 'Luncheon of the Boating Party',
    artist: 'Pierre-Auguste Renoir',
    year: '1881',
    sizeCm: '130 × 175 cm',
    school: '法国印象派',
    description: '阳光透过条纹遮阳篷洒在餐桌和笑脸上。朋友们在塞纳河畔共饮——这是印象派最欢乐的一幅画，青春与光影一同流动。',
    anchorX: -10.0, anchorZ: -5.0, facing: '+X',
  },
  {
    id: 'hopper_nighthawks',
    titleZh: '夜鹰',
    titleEn: 'Nighthawks',
    artist: 'Edward Hopper',
    year: '1942',
    sizeCm: '84.1 × 152.4 cm',
    school: '美国现实主义',
    description: '深夜的街角餐厅，四个人各怀心事。荧光灯照亮空荡的街道——霍珀画出了现代都市里最深的孤独。',
    anchorX: -10.0, anchorZ: 2.0, facing: '+X',
  },
  {
    id: 'giorgione_tempest',
    titleZh: '暴风雨',
    titleEn: 'The Tempest',
    artist: 'Giorgione',
    year: 'c.1508',
    sizeCm: '82 × 73 cm',
    school: '威尼斯画派',
    description: '士兵、喂奶的女人、远方的闪电——没人能确定这张画的主题。乔尔乔内把画的意义第一次让渡给了观者的想象。',
    anchorX: -0.69, anchorZ: -2.0, facing: '-X',
  },
  {
    id: 'uccello_san_romano',
    titleZh: '圣罗马诺之战',
    titleEn: 'The Battle of San Romano',
    artist: 'Paolo Uccello',
    year: 'c.1438–1440',
    sizeCm: '182 × 323 cm',
    school: '早期文艺复兴 · 佛罗伦萨',
    description: '倒地的长矛在地面汇聚于一点——这是一场几何学家画的战争。战马、铠甲、身体全被透视切割成可量化的立方体。',
    anchorX: -10.0, anchorZ: -2.0, facing: '+X',
  },
  {
    id: 'monet_sunrise',
    titleZh: '日出·印象',
    titleEn: 'Impression, Sunrise',
    artist: 'Claude Monet',
    year: '1872',
    sizeCm: '48 × 63 cm',
    school: '法国印象派',
    description: '勒阿弗尔港的日出，一轮橙红的太阳悬在薄雾中。这幅画的名字被一个批评家拿来嘲笑——于是有了"印象派"。',
    anchorX: 11.8, anchorZ: -7.5, facing: '+Z',
  },
  {
    id: 'klimt_kiss',
    titleZh: '吻',
    titleEn: 'The Kiss',
    artist: 'Gustav Klimt',
    year: '1908',
    sizeCm: '180 × 180 cm',
    school: '维也纳分离派',
    description: '一对恋人在金色光芒中相拥而吻。金箔、几何花纹与缠绕的身体——克里姆特把装饰艺术推向了情感表达的极致。',
    anchorX: -0.32, anchorZ: -2.0, facing: '+X',
  },
  {
    id: 'degas_dance',
    titleZh: '舞蹈课',
    titleEn: 'The Dance Class',
    artist: 'Edgar Degas',
    year: 'c.1874',
    sizeCm: '85 × 75 cm',
    school: '法国印象派',
    description: '芭蕾舞者在排练厅里伸展、调整舞鞋、等待自己的轮次。德加捕捉的不是舞台上的完美——而是练习中疲惫而真实的瞬间。',
    anchorX: -0.32, anchorZ: 2.0, facing: '+X',
  },
];

export function findExhibit(id: string): Exhibit | undefined {
  for (const e of DAVID_EXHIBITS) {
    if (e.id === id) return e;
  }
  return undefined;
}

const ACTIVATION_RADIUS: number = 2.5;

interface FacingXZ { x: number; z: number; }
function facingVec(f: Facing): FacingXZ {
  if (f === '+X') return { x: 1, z: 0 };
  if (f === '-X') return { x: -1, z: 0 };
  if (f === '+Z') return { x: 0, z: 1 };
  return { x: 0, z: -1 };
}

export function nearestExhibitId(playerX: number, playerZ: number): string {
  let bestId: string = '';
  let bestDist2: number = ACTIVATION_RADIUS * ACTIVATION_RADIUS;
  for (const e of DAVID_EXHIBITS) {
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
