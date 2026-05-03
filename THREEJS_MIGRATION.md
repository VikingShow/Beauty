# Three.js 迁移记录

## 架构

```
ArkTS 壳 (ThreeJsHost.ets)           Three.js Web 应用 (rawfile/web/)
┌──────────────────────────┐    ┌──────────────────────────────────┐
│ Web 组件                  │    │ index.html                       │
│ .javaScriptAccess(true)   │    │ ├── gltf_data.js (内嵌场景数据)    │
│ .domStorageAccess(true)   │    │ ├── importmap (CDN Three.js)     │
│ .onInterceptRequest(...)  │    │ └── <script type="module">      │
└──────────────────────────┘    │     GLTFLoader.parse()           │
                                │     → 3D 场景渲染 + FPS 控制      │
                                └──────────────────────────────────┘
```

## 踩坑记录

### 1. rawfile:// 协议被 CORS 阻止

**现象**: `fetch('rawfile://gltf/...')` → `Cross origin requests are only supported for protocol schemes: http, https, data, ...`

**根因**: HarmonyOS WebView CORS 白名单不包含 `rawfile://`。`onInterceptRequest` 在 CORS 检查**之后**才触发，无法绕过。

**解决**: 资源数据直接嵌入 HTML 为 JS 变量（`window.GLTF_DATA = {...}`），零网络请求。

### 2. ES Module 不能作为普通 script 加载

**现象**: `<script src="three.module.js"></script>` → 页面卡住，控制台报 `export` 语法错误

**根因**: ESM 文件包含 `export` 语句，必须通过 `<script type="module">` 或 importmap 加载。

**解决**: 使用 importmap + `<script type="module">` 加载 Three.js CDN。

### 3. importmap 可用性验证

**现象**: 最初不确定 HarmonyOS WebView 是否支持 `<script type="importmap">`

**验证**: 创建诊断页，用 importmap 加载 Three.js CDN 并渲染旋转立方体 → **成功**。

**结论**: HarmonyOS WebView (API 20) 完整支持 importmap + ESM。

### 4. 数据内嵌是最可靠的资源加载方式

**现象**: 尝试了 `$rawfile()` → `onInterceptRequest` → `rawfile://` → `http://rawfile.local/` → XHR → 全部失败

**最终方案**: Python 脚本将 glTF JSON + base64 纹理写入 `gltf_data.js`，HTML 用 `<script>` 标签加载。数据通过 `window.GLTF_DATA` 全局变量访问。

### 5. 设备网络

**现象**: Three.js CDN 在设备上加载失败（`ERR_INTERNET_DISCONNECTED`）

**说明**: 测试设备可能无网络或网络受限。本地 bundling 作为离线方案保留在 `rawfile/web/js/` 中。

## 技术决策

| 决策 | 原因 |
|------|------|
| CDN importmap | 无需管理大型 JS 文件，设备有网络时自动使用最新版 |
| 数据内嵌为 JS 变量 | 唯一能绕过 CORS 白名单的资源加载方式 |
| GLTFLoader.parse() | 直接解析 JS 变量中的 JSON，零网络请求 |
| 纹理 base64 内嵌 | 无需单独加载纹理文件，128KB 可接受 |
