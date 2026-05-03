# 虚拟布展器 · 项目计划

_最后更新：2026-04-24_

---

## 1. 愿景

一个帮助艺术家在**虚拟美术馆内布置自己作品**的跨端应用。艺术家上传场景模型与作品（或图片），在场景内调整位置、缩放、朝向，预览效果。后期支持一键在线分享，访客通过链接漫游其个人展。

**用户旅程**

1. 打开 App → 选场景（预置 or 自上传）
2. 上传作品（2D 图片 / 3D 模型）
3. 拖到场景里的槽位 → 自动吸附
4. 微调尺寸、旋转、位置
5. 切到预览模式 → 第一人称漫游自己的展览
6. （后期）发布 → 拿到分享链接

**目标平台**：鸿蒙 · Web · Windows · macOS · Android · iOS  
**起步平台**：鸿蒙 + Web（Windows 用 Electron 套壳基本白送）

---

## 2. 竞品扫描

| 产品 | 平台 | 自上传场景 | 槽位模板 | 定价 | 关键弱点 |
|---|---|---|---|---|---|
| Artsteps | Web / iOS / Android / Quest | ❌ 需付费定制 | ❌ | 免费基础 + 定制贵 | 上传限制严、画面老、无真正自上传 glTF 场景 |
| Kunstmatrix | Web / AR | ❌ 模板 or 买房间 | ❌ | €180–970 | 场景不可自定义 |
| ShapeSpark | Web / VR 浏览器 | ✅ 建筑级自上传 | ❌ | 订阅制 | 地产/展厅向，烘焙式渲染 |
| Exhibbit | Web | ❌ 固定模板 | ❌ | 订阅制 | 画风老 |
| Spatial.io | Web / iOS / Android / Quest | ✅ GLB/FBX/OBJ | ❌ | 免费增值 | NFT 社交向，UX 琐碎 |
| Mozilla Hubs | — | ✅ | ✅ (`MOZ_hubs_components`) | — | **已死 · 2024.5.31**；但 Spoke 编辑器开源 MIT，是最好的学习材料 |
| VRChat | Windows / Quest / 移动端 | ✅ Unity SDK | ✅ Unity prefab | 免费 | 锁 Unity 工具链、无 Web |

**缺口**：没人同时做到 (a) 接受用户自上传 glTF 场景 + (b) 解析模板化槽位 + (c) 鸿蒙端。**这是你的切入点**。

---

## 3. 技术栈决策

### 推荐方案 · **Three.js + 各平台壳**

| 平台 | 实现 |
|---|---|
| Web | 原生 Three.js |
| Windows / macOS | Electron / Tauri 套壳同一 Web |
| iOS / Android | Capacitor 套壳同一 Web |
| 鸿蒙 | ArkUI `Web` 组件嵌入同一 Web；或原生 ArkGraphics3D 作为"旗舰模式"备选渲染 |

**优势**：
- 一套 TS 代码跑全端
- 在线分享几乎免费（同一 URL 即可）
- `TransformControls` 支持鼠标 + 触摸
- 鸿蒙 NEXT `Web` 组件跑 WebGL 已有先例（Cocos Web3D 嵌入 HAP）

**代价**：
- 移动端 WebGL 性能不如原生
- 高阶 PBR 特性（HDR、屏幕空间反射）做不到
- 鸿蒙 ArkTS ↔ JS 文件桥接需要实测验证

### 拒绝的方案

- **Unity 团结引擎（Tuanjie）**：官方鸿蒙支持但**只在中国发行**；WebGL 包 20–40 MB，分享体验差
- **Filament / Babylon Native**：都无鸿蒙
- **Flutter 3D**：生态不成熟
- **每平台原生**：5 倍工作量

---

## 4. 文件格式策略

**"多格式进，glTF 出"** 统一路线：

1. 用户可上传 glTF / OBJ / FBX / DAE 等任意格式
2. 客户端（或云端）**即时转成 glTF**
3. 存储层只保留 glTF
4. 所有端只读 glTF

**转换工具**：
- `obj2gltf` (npm，纯 JS)
- `FBX2glTF` (Meta 开源，WASM 可用)
- `gltf-pipeline` (glTF 压缩优化)
- Blender CLI 批处理（最全但要装 Blender）

**避免**：让鸿蒙只支持 glTF、Windows 支持多格式——这种分裂会让用户在 Windows 上传的文件到鸿蒙打不开。

---

## 5. 槽位标注方案

**格式**：glTF 2.0（`.glb` 单文件优先）

**约定**：节点名前缀 + `extras` 元数据（Khronos 官方推荐的自定义元数据通道）

| 节点名前缀 | 用途 |
|---|---|
| `Slot_Painting_*` | 画作槽位（墙面） |
| `Slot_Sculpture_*` | 雕塑槽位（基座/地面） |
| `Slot_Spawn` | 访客初始位置 |
| `Slot_Waypoint_*` | 导览路径点 |

**每个槽位节点的 extras 字段**：

```json
{
  "slotType": "painting",
  "slotId": "north-wall-01",
  "maxWidth": 1.2,
  "maxHeight": 0.9,
  "facing": [0, 0, 1],
  "defaultArtwork": null,
  "label": "北墙主位"
}
```

**艺术家在 Blender 里的操作（3 步）**：

1. 在目标位置放一个 Empty（空物体），命名 `Slot_Painting_NorthWall01`
2. 让它的 +Z 朝向房间内（决定画作的正面方向）
3. 加 Custom Properties：`slotType`, `maxWidth`, `maxHeight` 等
4. 导出 glTF 时勾选 "Custom Properties"

**运行时**：扫 scene graph → 匹配 `Slot_*` 节点 → 读 `extras` → 渲染虚线框 → 拖作品进框即吸附。

**为什么不注册 KHR 扩展**：Khronos 扩展是给跨厂商互通用的；我们自己一个产品用 `extras` + 命名前缀是官方认可的路径。将来成熟了再提扩展不迟。

---

## 6. MVP（约两周）范围

1. **只做鸿蒙 + Web**，Windows 用 Electron 一周套壳
2. **预置 1 个场景**（3 画位 + 1 雕塑位 + 1 出生点），端到端验证槽位机制
3. **用户只能传 2D 图片**，暂不接 3D 作品 / 自上传 3D 场景——**砍掉 60% 风险面**
4. **编辑操作**：吸附到槽 + 按钮式 ±1cm / ±5° 微调，不做自由拖拽（手机端体验差）
5. **预览模式**：第一人称漫游，从 `Slot_Spawn` 起始
6. **不做在线分享**——导出本地 JSON 清单：
   ```json
   { "sceneId": "gallery-01", "placements": [
     { "slotId": "north-wall-01", "imageUrl": "...", "scale": 0.95 }
   ]}
   ```

---

## 7. 风险 · 优先级排序

1. **用户自上传 glTF 是安全雷区**（畸形文件、超高面数、恶意 shader）
   - **Mitigation**：MVP 只接 2D 图片，规避 90% 风险。3D 上传留到阶段 2：加 `gltf-validator`、面数上限（单作品 100k / 场景 500k）、贴图上限 2K、extras 白名单、CDN 加 `Content-Disposition: attachment`
2. **移动端 gizmo 操作难**（Three.js 论坛长期抱怨）
   - **Mitigation**：默认强制吸附槽 → 只提供按钮式 ±1cm / ±5° 微调；触摸设备上把 gizmo 控件放大 1.5-2×
3. **鸿蒙 WebView 桥接需实测**
   - **Mitigation**：起步第一天先做个 10 行 "hello WebGL" HAP 验证通路
4. **格式互通地狱**（Blender/Maya 导出的 up-axis / 单位 / 材质各不相同）
   - **Mitigation**：导入时统一归一化（bounding box → 已知尺寸、Y-up、1 单位 = 1m），给用户"效果对吗？"确认步骤
5. **存储成本 + 版权**（接 3D 上传后）
   - **Mitigation**：阶段 2 再考虑，参考 Sketchfab 免费配额 + ToS 声明

---

## 8. 差异化与野路子

- **"AI 自动布展"按钮**：读所有槽位 + 已上传作品，用色彩/比例/主题启发式（或多模态 LLM）生成一版布局。**竞品没人有**
- **Polycam 扫描入口**：2025.2 新功能——手机扫你的真实画廊 → 15 秒变 3D。可作上传入口，抹掉"学 Blender"门槛
- **Sketchfab URL 托管**：用户粘贴 Sketchfab 链接代替上传，零存储成本
- **鸿蒙旗舰机 ArkGraphics3D 原生路径**：预置场景走原生渲染显示质感差异，参赛加分项
- **`KHR_interactivity` 扩展**（2024.6 进入公开审查）：后续做"导览模式 / 触发动画"时可直接用，免自造脚本层

---

## 9. 参考资源

**开源项目**：
- `Hubs-Foundation/Spoke`（MIT）——Three.js 场景编辑器黄金参考
- `theringsofsaturn/3D-art-gallery-threejs`
- `clementcariou/virtual-art-gallery`

**规范**：
- glTF 2.0 Khronos 官方规范
- Blender glTF I/O 导出文档（Custom Properties 章节）
- `KHR_lights_punctual`、`KHR_interactivity`（公开审查中）

**安全**：
- Facebook 3D Model Validation Tool
- `gltf-validator` 命令行工具

---

## 10. 分阶段路线图

### 阶段 0 · 可行性验证（2-3 天）
纯 Web 单文件原型。目标：端到端验证"glTF 场景加载 + 槽位解析 + 图片挂载"可行。

### 阶段 1 · MVP（2 周）
鸿蒙 + Web 双端、1 个预置场景、图片上传与吸附、预览模式、导出 JSON。

### 阶段 2 · 扩展（2-3 周）
Electron Windows 壳、用户自上传场景（加校验）、3D 作品上传、多场景切换。

### 阶段 3 · 联网（3-4 周）
账号系统、云端存储（OSS）、分享链接、浏览公共展览。

### 阶段 4 · 增强（按需）
AI 自动布展、Polycam 扫描、鸿蒙原生渲染路径、导览模式 (`KHR_interactivity`)。
