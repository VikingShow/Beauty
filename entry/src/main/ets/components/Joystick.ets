const DEFAULT_SIZE: number = 160;
const KNOB_SIZE: number = 60;
const DEAD_ZONE: number = 0.08;

/**
 * 触屏虚拟摇杆。独立跟踪一个 touch id，不影响同屏其他区域的手势（如 3D 相机转视角）。
 * 输出归一化向量 (x, y) ∈ [-1, 1]；未操作时恒为 (0, 0)。
 *
 * 约定：
 *   +x = 屏幕右移 → 调用方用于 strafe 右
 *   +y = 屏幕下移 → 调用方通常取反当"前进"
 */
@Component
export struct Joystick {
  onInput: (x: number, y: number) => void = (x: number, y: number) => {};

  @State private knobX: number = 0;
  @State private knobY: number = 0;
  @State private active: boolean = false;

  private touchId: number = -1;
  private readonly stickSize: number = DEFAULT_SIZE;
  private readonly maxRadius: number = (DEFAULT_SIZE - KNOB_SIZE) / 2;

  private updateKnob(localX: number, localY: number): void {
    const cx: number = this.stickSize / 2;
    const cy: number = this.stickSize / 2;
    let dx: number = localX - cx;
    let dy: number = localY - cy;
    const dist: number = Math.sqrt(dx * dx + dy * dy);
    if (dist > this.maxRadius) {
      const scale: number = this.maxRadius / dist;
      dx *= scale;
      dy *= scale;
    }
    this.knobX = dx;
    this.knobY = dy;

    const nx: number = dx / this.maxRadius;
    const ny: number = dy / this.maxRadius;
    const mag: number = Math.sqrt(nx * nx + ny * ny);
    if (mag < DEAD_ZONE) {
      this.onInput(0, 0);
    } else {
      this.onInput(nx, ny);
    }
  }

  private reset(): void {
    this.knobX = 0;
    this.knobY = 0;
    this.active = false;
    this.touchId = -1;
    this.onInput(0, 0);
  }

  build() {
    Stack() {
      // 背景圈
      Circle()
        .width(this.stickSize)
        .height(this.stickSize)
        .fill(this.active ? '#0a0a1aCC' : '#0a0a1a88')
        .stroke('#d4b678AA')
        .strokeWidth(2)

      // 中心十字提示
      Text('+')
        .fontSize(14)
        .fontColor('#d4b67844')
        .position({ x: this.stickSize / 2 - 4, y: this.stickSize / 2 - 10 })

      // 摇杆头
      Circle()
        .width(KNOB_SIZE)
        .height(KNOB_SIZE)
        .fill(this.active ? '#d4b678EE' : '#d4b67899')
        .stroke('#ffffff88')
        .strokeWidth(1)
        .position({
          x: (this.stickSize - KNOB_SIZE) / 2 + this.knobX,
          y: (this.stickSize - KNOB_SIZE) / 2 + this.knobY
        })
    }
    .width(this.stickSize)
    .height(this.stickSize)
    .onTouch((event: TouchEvent) => {
      const changed = event.changedTouches;
      if (changed === undefined || changed.length === 0) {
        return;
      }
      const eventType: TouchType = event.type;

      if (eventType === TouchType.Down && this.touchId < 0) {
        const t: TouchObject = changed[0];
        this.touchId = t.id;
        this.active = true;
        this.updateKnob(t.x, t.y);
        return;
      }

      for (const t of changed) {
        if (t.id !== this.touchId) {
          continue;
        }
        if (eventType === TouchType.Move) {
          this.updateKnob(t.x, t.y);
        } else if (eventType === TouchType.Up || eventType === TouchType.Cancel) {
          this.reset();
        }
      }
    })
  }
}
