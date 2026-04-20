import { Doorway, InternalWall, RoomLayout, Waypoint } from '../scenes/Waypoint';

const MAP_MAX_PX: number = 220;
const DOT_SIZE: number = 14;
const PLAYER_SIZE: number = 16;
const WALL_THICKNESS: number = 3;

interface WallSegment {
  x1: number;
  x2: number;
}

/**
 * 矩形俯视小地图，按真实房间比例绘制，
 * 显示外墙轮廓 + 内墙（带门洞间隙）+ 航点 + 玩家朝向。
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

  private wx(x: number): number {
    return this.mapW() / 2 + x * this.pxPerMeter();
  }

  private wy(z: number): number {
    return this.mapH() / 2 + z * this.pxPerMeter();
  }

  /** 把一道内墙拆成若干"门洞间"墙段，便于绘制时跳过门洞。 */
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

  build() {
    Stack() {
      // 底板
      Column()
        .width(this.mapW())
        .height(this.mapH())
        .backgroundColor('#0a0a1aDD')
        .borderColor('#d4b678')
        .borderWidth(1.5)

      // 北方向标记
      Text('N')
        .fontSize(11)
        .fontColor('#d4b678')
        .position({ x: this.mapW() / 2 - 4, y: 4 })

      // 内墙（每道墙拆成多个段，跳过门洞）
      ForEach(this.layout.internalWalls, (wall: InternalWall) => {
        ForEach(this.wallSegments(wall), (seg: WallSegment) => {
          Column()
            .width((seg.x2 - seg.x1) * this.pxPerMeter())
            .height(WALL_THICKNESS)
            .backgroundColor('#d4b678BB')
            .position({
              x: this.wx(seg.x1),
              y: this.wy(wall.z) - WALL_THICKNESS / 2
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
            x: this.wx(wp.position.x) - DOT_SIZE / 2,
            y: this.wy(wp.position.z) - DOT_SIZE / 2
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
          angle: -this.playerYaw * 180 / Math.PI,
          centerX: '50%',
          centerY: '50%'
        })
        .position({
          x: this.wx(this.playerX) - PLAYER_SIZE / 2,
          y: this.wy(this.playerZ) - PLAYER_SIZE / 2
        })
    }
    .width(this.mapW())
    .height(this.mapH())
  }
}
