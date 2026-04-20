export interface Vec3 {
  x: number;
  y: number;
  z: number;
}

export function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

/** 取最短路径对角度插值（处理 ±π 的环回）。 */
export function lerpAngle(a: number, b: number, t: number): number {
  let diff: number = b - a;
  while (diff > Math.PI) {
    diff -= 2 * Math.PI;
  }
  while (diff < -Math.PI) {
    diff += 2 * Math.PI;
  }
  return a + diff * t;
}

/** 0-1 → smoothstep（三次平滑缓动）。 */
export function smoothstep(t: number): number {
  return t * t * (3 - 2 * t);
}
