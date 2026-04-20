import { Waypoint } from '../scenes/Waypoint';

const MAP_SIZE: number = 180;
const MAP_RADIUS: number = 80;
const DOT_SIZE: number = 14;
const PLAYER_SIZE: number = 16;

/**
 * 圆形画廊的俯视小地图。
 * - 外圈代表画廊墙壁
 * - 黄色实心圆点为当前所在航点，灰色环点为可传送航点
 * - 红色三角为玩家自身位置 + 朝向
 *
 * 坐标映射：世界 (X, Z) → 屏幕 (cx + X * scale, cy + Z * scale)
 * 上=北=−Z 方向；下=南=+Z 方向。
 */
@Component
export struct Minimap {
  waypoints: Waypoint[] = [];
  @Prop currentWaypointId: string = '';
  @Prop playerX: number = 0;
  @Prop playerZ: number = 0;
  @Prop playerYaw: number = 0;
  worldRadius: number = 5.5;
  onWaypointTap: (wp: Waypoint) => void = (wp: Waypoint) => {};

  private worldToMap(coord: number): number {
    return coord * (MAP_RADIUS / this.worldRadius);
  }

  private centerPx(): number {
    return MAP_SIZE / 2;
  }

  build() {
    Stack() {
      // 外圈：画廊轮廓
      Circle()
        .width(MAP_RADIUS * 2)
        .height(MAP_RADIUS * 2)
        .fill('#0a0a1aDD')
        .stroke('#d4b678')
        .strokeWidth(1.5)

      // 北向标记
      Text('N')
        .fontSize(10)
        .fontColor('#d4b678')
        .position({ x: this.centerPx() - 4, y: this.centerPx() - MAP_RADIUS + 2 })

      // 中心十字
      Text('+')
        .fontSize(10)
        .fontColor('#4a4a5a')
        .position({ x: this.centerPx() - 3, y: this.centerPx() - 6 })

      // 航点圆点
      ForEach(this.waypoints, (wp: Waypoint) => {
        Circle()
          .width(DOT_SIZE)
          .height(DOT_SIZE)
          .fill(this.currentWaypointId === wp.id ? '#d4b678' : '#665a44')
          .stroke('#d4b678')
          .strokeWidth(1)
          .position({
            x: this.centerPx() + this.worldToMap(wp.position.x) - DOT_SIZE / 2,
            y: this.centerPx() + this.worldToMap(wp.position.z) - DOT_SIZE / 2
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
          x: this.centerPx() + this.worldToMap(this.playerX) - PLAYER_SIZE / 2,
          y: this.centerPx() + this.worldToMap(this.playerZ) - PLAYER_SIZE / 2
        })
    }
    .width(MAP_SIZE)
    .height(MAP_SIZE)
  }
}
