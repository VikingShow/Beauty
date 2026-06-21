# 艺树 · ArTree

鸿蒙 6.0 原生 3D 艺术馆探索 + 推理解谜应用，基于 ArkGraphics 3D + ArkUI。

**目标平台**：HarmonyOS 6.0+
**目标设备**：平板 / 2in1 / 手机 / PC，横屏。
**技术栈**：ArkTS / ArkUI / ArkGraphics 3D / Core Speech Kit / Python（离线资产生成）。

---

## 当前功能

### 核心玩法
- **大卫馆 · 根特悬案** — 载入文艺复兴艺术馆模型（Zeps3D, CC-BY 4.0），展出 18 幅名画，内置侦探解谜主线。
- **画中世界** — 走近画作后可"走入画中"，每幅画有独特 3D 微缩场景，支持深度估计→浮雕地形。
- **侦探推理系统** — 6 条隐藏线索散布在特定画作中，集齐后可唯一锁定"失窃名画"藏身处。
- **AI 语音旁白** — 基于鸿蒙 Core Speech Kit，开场独白 + 线索发现时语音播报，营造沉浸式夜间艺术馆氛围。

### 交互
- **第一人称视角**：拖动转视角（yaw / pitch），四元数 slerp 平滑传送。
- **自由移动**：左下角虚拟摇杆，WASD 式前后左右，步速 2 m/s。
- **定点传送**：点击底部航点按钮或小地图金色圆点，平滑过渡。
- **矢量小地图**：右上角，按真实世界坐标绘制房间轮廓 / 展品位置 / 玩家朝向。
- **AABB 碰撞**：外墙限制 + 展品障碍物滑动碰撞（雕像基座、树雕罩等）。

### 3D 与视觉
- 真实 PBR 材质 + 4 盏方向光（主光 + 冷色补光 + 暖色侧光 + 天顶补光），实时光影。
- 18 幅文艺复兴名画纹理（达芬奇、拉斐尔、波提切利、米开朗基罗等）。
- 模糊透明美学 UI（毛玻璃模态、半透明 HUD 面板）。
- glTF 节点矩阵解析，自动提取世界坐标范围。

### 鸿蒙创新方向覆盖

| 方向 | 实现 |
|------|------|
| **3D 空间化** | ArkGraphics 3D 第一人称漫游、画中世界 3D 场景、AABB 碰撞 + 物理重力跳跃、PBR 渲染 |
| **AI 智能化体验** | 深度估计→3D 浮雕地形、Core Speech Kit AI 语音旁白（开场独白 + 画作导览 + 线索播报） |
| **安全隐私保护** | [待补充] |
| **全场景一体协同** | [待补充] |

---

## 架构

```
entry/src/main/ets/
├── controllers/
│   ├── CameraController.ets                 虚基类
│   ├── OrbitCameraController.ets            轨道相机（绕原点）
│   └── FirstPersonCameraController.ets      第一人称 + 移动 + 碰撞
├── components/
│   ├── Minimap.ets                          矢量小地图
│   ├── Joystick.ets                         虚拟摇杆（独立 touch id）
│   ├── ExhibitCard.ets                      画作信息卡（走近自动弹出）
│   ├── ObservationModal.ets                 观察模态（发现线索 + 收入笔记）
│   └── NotebookModal.ets                    侦探笔记模态（线索+推理筛选）
├── scenes/
│   ├── Waypoint.ets                         航点 + RoomLayout + SceneFeature 数据
│   ├── Exhibits.ets                         18 幅文艺复兴名画元数据
│   ├── Clues.ets                            根特悬案 · 6 条线索 + 推理引擎
│   ├── WhiteCubeSlots.ets                   白盒展厅布展槽位
│   └── SalonCarreSlots.ets                  沙龙展厅布展槽位
├── pages/
│   ├── Index.ets                            主菜单
│   ├── DavidScene.ets                       大卫馆 · 根特悬案（主关卡）
│   ├── GalleryScene.ets                     白盒展厅
│   ├── GameScene.ets                        轨道相机测试
│   └── ThreeJsHost.ets                      Three.js WebView 实验路径
├── utils/
│   ├── Types.ets                            Vec3 / lerp / smoothstep
│   └── SpeechEngine.ets                     Core Speech Kit TTS 封装
└── entryability/
    └── EntryAbility.ets                     全屏/锁横屏

scripts/
├── generate_gallery.py                      生成白盒展厅 glTF + 程序化纹理
├── parse_david.py                           解析 David 场景 glTF 节点矩阵
├── generate_paintings.py                    生成画作纹理贴图
└── depth_estimate.py                        深度估计 → 画中世界 3D 浮雕

entry/src/main/resources/rawfile/gltf/
├── David/                                   大卫馆资产（CC-BY 4.0）
├── gallery/                                 生成的白盒展厅
└── DamagedHelmet/                           Phase 0 测试模型
```

---

## 控制一览

| 操作 | 效果 |
|---|---|
| 拖动屏幕（非摇杆区域） | 转视角 |
| 左下角摇杆 | 前后左右自由移动 |
| 点击底部航点按钮 | 平滑传送到该航点 |
| 点击小地图上的金色圆点 | 同上 |
| 走近画作 | 自动弹出信息卡 + AI 语音旁白 |
| 点击"深入观察" | 观察模态（发现线索 + 语音播报窃语） |
| 点击右侧线索计数器 | 打开侦探笔记 |
| 画中世界：双击屏幕 | 跳跃（重力物理） |
| ← 返回 | 回主菜单 |

---

## 已知限制

| # | 问题 | 计划 |
|---|---|---|
| 1 | David alcove 曲面墙可穿过 | 补手工 collider |
| 2 | 相机 Y 高度固定，无法上楼梯 | 加斜面/台阶处理 |
| 3 | details_emissive.png 被替换为全黑 | 从 Sketchfab 下载原资源 |
| 4 | 缺少物理引擎（重力/跳跃） | 画中世界已接入重力+跳跃（WebView 路径），原生路径待补充 |

---

## 开发 Roadmap

- [x] **Phase 0** 环境验证（Hello 3D）
- [x] **Phase 1** 核心 3D 漫游 + 架构
- [x] **Phase 2** 展品交互 + 信息卡 + 语音旁白
- [x] **Phase 3** 剧情 + 侦探推理系统
- [x] **Phase 4** 画中世界副本（深度估计 → 3D 浮雕地形）
- [ ] **Phase 5** 全场景协同 + 多设备适配 + 致谢页 + 原生物理引擎

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
