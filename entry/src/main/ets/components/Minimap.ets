import { Doorway, InternalWall, RoomLayout, SceneFeature, Waypoint } from '../scenes/Waypoint';

const MAP_MAX_PX: number = 220;
const DOT_SIZE: number = 14;
const PLAYER_SIZE: number = 16;
const WALL_THICKNESS: number = 3;

interface WallSegment {
  x1: number;
  x2: number;
}

interface MapBox {
  x: number;
  y: number;
  w: number;
  h: number;
}

/**
 * 俯视小地图。按真实世界坐标矢量绘制：
 *   外墙 → 底板边框 + 地板色
 *   features → 展品/障碍物矩形
 *   waypoints → 金色圆点
 *   玩家 → 红色三角（带朝向旋转）
 *
 * 支持 worldCenterX/Z 偏移（当模型原点不在几何中心时），
 * 以及 imageNorthYawOffset（让小地图"上方"对齐世界中任意方向）。
 */
@Component
export struct Minimap {
  waypoints: Waypoint[] = [];
  layout: RoomLayout = { worldWidth: 1, worldDepth: 1, internalWalls: [] };
  @Prop currentWaypointId: string = '';
  @Prop playerX: number = 0;
  @Prop playerZ: number = 0;
  @Prop playerYaw: number = 0;
  onWaypointTap: (wp: Waypoint) => void = (wp: Waypoint) => {};
我的
  private pxPerMeter(): number {
    const m: number = Math.max(this.layout.worldWidth, this.layout.worldDepth);
    return m > 0 ? MAP_MAX_PX / m : 1;
  }

  private mapW(): number {
    return this.layout.worldWidth * this.pxPerMeter();
  }

  private mapH(): number {
    return this.layout.worldDepth * this.pxPerMeter();
  }

  /** 世界 (x, z) → 小地图像素。按 imageNorthYawOffset 旋转 + worldCenter 偏移。 */
  private wx(x: number, z: number): number {
    const theta: number = this.layout.imageNorthYawOffset ?? 0;
    const cx: number = this.layout.worldCenterX ?? 0;
    const cz: number = this.layout.worldCenterZ ?? 0;
    const dx: number = x - cx;
    const dz: number = z - cz;
    return this.mapW() / 2 + (dx * Math.cos(theta) - dz * Math.sin(theta)) * this.pxPerMeter();
  }

  private wy(x: number, z: number): number {
    const theta: number = this.layout.imageNorthYawOffset ?? 0;
    const cx: number = this.layout.worldCenterX ?? 0;
    const cz: number = this.layout.worldCenterZ ?? 0;
    const dx: number = x - cx;
    const dz: number = z - cz;
    return this.mapH() / 2 + (dx * Math.sin(theta) + dz * Math.cos(theta)) * this.pxPerMeter();
  }

  /** 把一个世界 AABB 转为小地图像素矩形（4 个角取包络，支持 90° 倍数旋转）。 */
  private featureBox(f: SceneFeature): MapBox {
    const xs: number[] = [
      this.wx(f.minX, f.minZ), this.wx(f.maxX, f.minZ),
      this.wx(f.maxX, f.maxZ), this.wx(f.minX, f.maxZ)
    ];
    const ys: number[] = [
      this.wy(f.minX, f.minZ), this.wy(f.maxX, f.minZ),
      this.wy(f.maxX, f.maxZ), this.wy(f.minX, f.maxZ)
    ];
    const xMin: number = Math.min(xs[0], xs[1], xs[2], xs[3]);
    const xMax: number = Math.max(xs[0], xs[1], xs[2], xs[3]);
    const yMin: number = Math.min(ys[0], ys[1], ys[2], ys[3]);
    const yMax: number = Math.max(ys[0], ys[1], ys[2], ys[3]);
    return { x: xMin, y: yMin, w: xMax - xMin, h: yMax - yMin };
  }

  /** 把一道内墙拆成若干"门洞间"墙段（仅 θ=0 场景，不参与坐标旋转）。 */
  private wallSegments(wall: InternalWall): WallSegment[] {
    const segs: WallSegment[] = [];
    const halfW: number = this.layout.worldWidth / 2;
    const sorted: Doorway[] = wall.doorways.slice().sort(
      (a: Doorway, b: Doorway): number => a.xStart - b.xStart
    );
    let cursor: number = -halfW;
    for (const d of sorted) {
      if (d.xStart > cursor) {
        const seg: WallSegment = { x1: cursor, x2: d.xStart };
        segs.push(seg);
      }
      cursor = d.xEnd;
    }
    if (cursor < halfW) {
      const seg: WallSegment = { x1: cursor, x2: halfW };
      segs.push(seg);
    }
    return segs;
  }

  /** 玩家三角形的旋转角（度）。 */
  private triangleAngleDeg(): number {
    const theta: number = this.layout.imageNorthYawOffset ?? 0;
    return -(this.playerYaw - theta) * 180 / Math.PI;
  }

  build() {
    Stack() {
      // 底板（深底 + 金色描边当外墙）
      Column()
        .width(this.mapW())
        .height(this.mapH())
        .backgroundColor('#1a1a24EE')
        .borderColor('#d4b678')
        .borderWidth(1.5)

      // 可选：用户提供的俯视缩略图（David 场景已改矢量，不需要）
      if (this.layout.floorplanImage !== undefined) {
        Image(this.layout.floorplanImage)
          .width(this.mapW())
          .height(this.mapH())
          .objectFit(ImageFit.Fill)
          .opacity(0.75)
      }

      // features：展品 / 障碍物矩形
      ForEach(this.layout.features ?? [], (f: SceneFeature) => {
        Column()
          .width(this.featureBox(f).w)
          .height(this.featureBox(f).h)
          .backgroundColor(f.color)
          .position({ x: this.featureBox(f).x, y: this.featureBox(f).y })
      }, (f: SceneFeature) => f.id)

      // 北方向标记
      Text('N')
        .fontSize(11)
        .fontColor('#d4b678')
        .position({ x: this.mapW() / 2 - 4, y: 4 })

      // 内墙（Gallery 场景使用）
      ForEach(this.layout.internalWalls, (wall: InternalWall) => {
        ForEach(this.wallSegments(wall), (seg: WallSegment) => {
          Column()
            .width((seg.x2 - seg.x1) * this.pxPerMeter())
            .height(WALL_THICKNESS)
            .backgroundColor('#d4b678BB')
            .position({
              x: this.wx(seg.x1, wall.z),
              y: this.wy(seg.x1, wall.z) - WALL_THICKNESS / 2
            })
        }, (seg: WallSegment) => `${wall.z}_${seg.x1}_${seg.x2}`)
      }, (wall: InternalWall) => `wall_${wall.z}`)

      // 航点圆点
      ForEach(this.waypoints, (wp: Waypoint) => {
        Circle()
          .width(DOT_SIZE)
          .height(DOT_SIZE)
          .fill(this.currentWaypointId === wp.id ? '#d4b678' : '#665a44')
          .stroke('#d4b678')
          .strokeWidth(1)
          .position({
            x: this.wx(wp.position.x, wp.position.z) - DOT_SIZE / 2,
            y: this.wy(wp.position.x, wp.position.z) - DOT_SIZE / 2
          })
          .onClick(() => {
            this.onWaypointTap(wp);
          })
      }, (wp: Waypoint) => wp.id)

      // 玩家朝向三角
      Polygon()
        .width(PLAYER_SIZE)
        .height(PLAYER_SIZE)
        .points([
          [PLAYER_SIZE / 2, 0],
          [3, PLAYER_SIZE - 2],
          [PLAYER_SIZE - 3, PLAYER_SIZE - 2]
        ])
        .fill('#ff6b6b')
        .stroke('#ffffff')
        .strokeWidth(0.5)
        .rotate({
          angle: this.triangleAngleDeg(),
          centerX: '50%',
          centerY: '50%'
        })
        .position({
          x: this.wx(this.playerX, this.playerZ) - PLAYER_SIZE / 2,
          y: this.wy(this.playerX, this.playerZ) - PLAYER_SIZE / 2
        })
    }
    .width(this.mapW())
    .height(this.mapH())
  }
}
