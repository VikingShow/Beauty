# 夜游艺术馆 · Night at the Gallery

鸿蒙 6.0 原生 3D 艺术馆探索应用，基于 ArkGraphics 3D + ArkUI。

**目标设备**：平板 / 2in1，横屏。
**技术栈**：ArkTS / ArkUI / ArkGraphics 3D / Python（离线资产生成）。

---

## 当前功能（Phase 1 完成）

### 关卡
- **第一关 · David** — 载入外部艺术馆模型（Zeps3D, CC-BY 4.0），展示 David 雕像、树雕、座椅等。
- **展厅漫游（白盒）** — Python 程序化生成的三厅展馆，测试基础渲染。
- **3D 轨道相机** — Phase 0 遗留测试页，绕头盔旋转+缩放。

### 交互
- **第一人称视角**：拖动转视角（yaw / pitch）。
- **自由移动**：左下角虚拟摇杆，WASD 式前后左右，步速 2 m/s。
- **定点传送**：点击底部航点按钮或小地图上的金色圆点，平滑过渡到指定位置。
- **矢量小地图**：右上角，按真实世界坐标绘制房间轮廓 / 展品位置 / 玩家朝向。
- **碰撞**：外墙 AABB 限制 + 展品障碍物滑动碰撞（如 David 基座、树雕罩）。

### 3D 与视觉
- 真实 PBR 材质（第一关）+ 自生成的瓷砖/涂料/天花板贴图（白盒展厅）。
- 4 盏方向光（主光 + 冷色补光 + 暖色侧光 + 天顶补光），实时光影。
- 模型 glTF 节点矩阵解析，自动提取世界坐标范围，支持非标准朝向的场景。

---

## 架构

```
entry/src/main/ets/
├── controllers/
│   ├── CameraController.ets            虚基类
│   ├── OrbitCameraController.ets       轨道相机（绕原点）
│   └── FirstPersonCameraController.ets 第一人称 + 移动 + 碰撞
├── components/
│   ├── Minimap.ets                     矢量小地图
│   └── Joystick.ets                    虚拟摇杆（独立 touch id）
├── scenes/
│   └── Waypoint.ets                    航点 + RoomLayout + SceneFeature 数据
├── pages/
│   ├── Index.ets                       主菜单
│   ├── DavidScene.ets                  第一关（David 艺术馆）
│   ├── GalleryScene.ets                白盒展厅
│   └── GameScene.ets                   轨道相机测试
├── utils/
│   └── Types.ets                       Vec3 / lerp / smoothstep
└── entryability/
    └── EntryAbility.ets                全屏/锁横屏

scripts/
└── generate_gallery.py                 生成白盒展厅 glTF + 程序化纹理

entry/src/main/resources/rawfile/gltf/
├── David/                              第一关资产（CC-BY 4.0）
├── gallery/                            生成的白盒展厅
└── DamagedHelmet/                      Phase 0 测试模型
```

---

## 控制一览（第一关）

| 操作 | 效果 |
|---|---|
| 拖动屏幕（非摇杆区域） | 转视角 |
| 左下角摇杆 | 前后左右自由移动 |
| 点击底部航点按钮 | 平滑传送到该航点 |
| 点击小地图上的圆点 | 同上 |
| ← 返回 | 回主菜单 |

---

## 已知限制

| # | 问题 | 计划 |
|---|---|---|
| 1 | David alcove 的**曲面墙可穿过** —— 只有 David 基座和树雕罩有 collider，alcove 的弧形展示墙还没建 | Phase 2+ 补手工 collider |
| 2 | **相机 Y 高度固定**，无法上楼梯 —— 楼梯下沉区域是展厅入口台阶，当前直接无视 | Phase 2+ 加斜面/台阶处理 |
| 3 | David 场景的 `details_emissive.png` 被替换为全黑 —— 原图是 1-bit 位图 ArkGraphics 加载异常，LED 高光细节丢失 | 有时间重新从 Sketchfab 下载原资源 |
| 4 | 小地图内墙段（Gallery 场景）不参与 imageNorthYawOffset 旋转 —— 现有场景 θ=0，不触发 | 如果以后 Gallery 需要旋转则修 |

---

## 开发 Roadmap

- [x] **Phase 0** 环境验证（Hello 3D）
- [x] **Phase 1** 核心 3D 漫游
  - [x] 1A 代码架构重构（Controller 模块化）
  - [x] 1B 第一人称相机 + 定点漫游 + 四元数 slerp 传送
  - [x] 1C 展厅场景 + 矩形小地图 + 白盒生成器
  - [x] 自由移动（虚拟摇杆 + AABB 碰撞）
  - [x] 矢量小地图（从 glTF 坐标解析绘制）
  - [x] 第一关 David 场景接入
- [ ] **Phase 2** 展品交互 + 介绍 UI
- [ ] **Phase 3** 剧情 + 推理系统
- [ ] **Phase 4** 画中世界副本
- [ ] **Phase 5** 打磨 + 致谢页 + 一多流转（加分项）

---

## 致谢

第三方资产详见 [CREDITS.md](CREDITS.md)。主要引用：
- **Art Gallery** by Zeps3D — CC-BY 4.0
- **Damaged Helmet** by Khronos Group / theblueturtle_ — CC-BY 4.0

---

## 运行

1. 打开 DevEco Studio，HarmonyOS 6.0 API 20
2. 连接平板真机（推荐 MatePad 系列）
3. `Build → Clean Project`
4. 运行；首次需要信任开发者签名

## 开发

白盒展厅需要重新生成时：
```bash
python scripts/generate_gallery.py
```
（需要 Python 3.8+ 和 Pillow：`pip install Pillow`）
