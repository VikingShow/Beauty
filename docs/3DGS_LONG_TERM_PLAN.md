# ArTree 3DGS 长期计划

目标：把华为 HarmonyOS 6 的 3D Gaussian Splatting 能力，收敛成 `beauty / ArTree` 里的一个可落地试点，再逐步扩展成可维护的长期能力。

## 总原则

1. 先做一个场景，不先重写全项目。
2. 保留现有 `ArkGraphics 3D + ArkUI + WebView` 路线，3DGS 只能做增强和试点。
3. 以设备实测结果为准，先看加载、帧率、交互、回退。
4. 资产优先于算法炫技，先保证场景内容和体验完整。

## 现状

- 已有西方馆和中国馆两条主线。
- 已有 `ThreeJsHost` 和 `depth_estimate.py`，说明项目已经具备“离线生成 + 局部 3D 化”的基础。
- 当前最适合 3DGS 的位置，是 `中国馆` 里的一个独立画作世界或一个独立展区。
- 华为官方已提供 `Spatial Recon Kit`，3DGS 支持 `MP4 / PLY / GLB`，并有加载、滤镜和渲染对象 API。

## 阶段路线

### Phase 0. 选点和约束确认

目标：
- 明确第一个 3DGS 试点场景。
- 明确输入资产格式、性能底线、回退策略。

建议试点：
- 先选 `中国馆` 中一幅山水画对应的 `painting world`。
- 首选 `xiao_xiang`，备选 `fuchun_shanju`。
- 这两个点都比人物画更适合 3DGS 的体积感表达。

验收：
- 能说清楚这个点为什么适合 3DGS。
- 能说清楚失败时退回哪条现有路径。

### Phase 1. 3DGS 试点验证

目标：
- 在 HarmonyOS 目标设备上跑通一个最小 3DGS 场景。
- 只验证“能加载、能显示、能切换、能退出”。

工作项：
- 找到官方 3DGS 能力的最小接入方式。
- 准备一个单独的测试场景，不碰主线逻辑。
- 记录支持的模型格式、资源体积、首帧时间、稳定性。

验收：
- 场景可进入。
- 场景可退出。
- 不影响现有主流程。

### Phase 2. 接入 ArTree 主项目

目标：
- 把 3DGS 变成一个可从主菜单进入的正式入口。
- 保留原来的 ArkGraphics / WebView 路径做 fallback。

工作项：
- 给 `Index` 增加一个明确的试点入口。
- 给 `ChineseGalleryScene` 增加 3DGS 场景切换层。
- 定义统一的场景配置结构，避免分叉失控。
- 抽出一个 `PaintingWorldProvider` 或同类适配层，把 `ArkGraphics 3D`、`WebView`、`3DGS` 三条路径纳入同一入口。

验收：
- 用户能在主界面进入 3DGS 试点。
- 设备不支持或加载失败时自动回退。

### Phase 3. 内容扩展

目标：
- 从单点试验扩展到一组可复用的“画作世界”模板。

工作项：
- 选 2 到 3 个最适合做体积感的画作做扩展。
- 建立资产规范：命名、尺寸、体积、LOD、回退图。
- 把现有 `depth_estimate.py` 的思路升级成更稳的生成流水线。

验收：
- 3DGS 不是单一 demo，而是能复用的内容管线。

### Phase 4. 设备和体验优化

目标：
- 针对手机、平板、2in1、PC 做体验分层。

工作项：
- 调整默认质量档位。
- 处理加载占位、过渡动画、低端设备降级。
- 明确音频、字幕、镜头控制与 3DGS 的关系。

验收：
- 启动不卡死。
- 场景不卡顿到不可用。
- 交互逻辑和现有项目一致。

### Phase 5. 长期演进

目标：
- 把 3DGS 变成 ArTree 的核心表现力之一，而不是临时特效。

方向：
- 多场景协同。
- 观展记录与推荐。
- 用户上传内容的审核和生成链路。
- 与现有线索系统、语音系统、展厅系统打通。

## 当前最近一步

1. 锁定第一个 3DGS 试点画作或展区。
2. 明确 HarmonyOS 目标设备和最小验收标准。
3. 在项目里加一个独立的 3DGS 入口或试验页。
4. 跑通后再决定是否进入主馆。
5. 再把 `ChineseGalleryScene` 的对应画作切到 3DGS 版本。

## 参考

- [HarmonyOS Spatial Recon Kit 介绍](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/spatial-recon-introduction)
- [HarmonyOS Spatial Recon Kit 指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/spatial-recon-kit-guide)
- [HarmonyOS 6.0.1 版本说明](https://developer.huawei.com/consumer/cn/doc/harmonyos-releases/os-new-feature-601)
