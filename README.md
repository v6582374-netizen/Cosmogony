# Cosmogony

Cosmogony 是一个 macOS 优先的灵感捕获与链接整理工具，当前由本地桌面应用和轻量 Chromium Companion Extension 组成。

这次版本重点完成了三件事：

- 主界面从“系统表格感”重构为更接近 `mymind` 气质的安静内容画布
- 修复自绘按钮只点文字才生效的问题，统一扩大整块点击热区
- 为每个平台分类内置 3 个真实网址作为默认样例，方便开箱验收 UI、分类和搜索

当前阶段又继续补齐了几条真正影响日常使用的交互闭环：

- 顶部搜索 + 下拉筛选替代旧侧边主控区，主窗口更接近 `mymind` 的第一视觉节奏
- 剪藏详情卡片改为限高可滚动，并支持直接编辑 `summary`
- 新增重复链接提醒、未保存退出提醒、置顶、左划删除，以及 trash 30 天自动清理

## 项目结构

- `apps/macos/`: SwiftUI + AppKit 桌面端，负责本地数据库、快捷键、菜单栏、bridge server、Provider 配置
- `extensions/chromium/`: Companion Extension，负责采集当前页面与选中文本并转发到本地 app
- `legacy/chrome-extension/`: 旧版 MuseMark 扩展归档，仅作为迁移参考
- `docs/`: 架构与迁移说明
- `tools/python/`: Python 辅助脚本

## 当前产品状态

当前活跃运行时已经收敛为 macOS-first 方案：

- 本地优先存储
- 全局快捷键采集当前网页与剪贴板
- 平台桶分类：`X帖子 / 小红书 / 微信公众号 / 抖音 / YouTube / 其余网页`
- 时间盒筛选
- 顶部搜索栏与 `Settings / Platforms / View Scope / Spaces` 下拉菜单
- 网站 favicon 优先显示，失败时自动回退平台图标
- 详情卡片内联编辑 `summary / category / tags / note / status`
- 剪藏去重提示，允许用户取消或继续添加重复链接
- 置顶排序与垃圾箱 30 天自动清理
- 本地 Provider Profile 管理，API Key 存入 Keychain
- 兼容旧版 MuseMark JSON 导入导出

已移除的旧能力包括：

- QuickDock
- 云同步 / Supabase 运行时依赖
- 原浏览器侧管理端与配置端运行时

## UI 重构说明

新版主窗口不再以系统 `List` 为主，而是改成两层内容结构：

1. 顶部为主搜索栏、快速清空 / 重置按钮，以及 `Settings / Platforms / View Scope / Spaces` 下拉筛选
2. 主体左侧为辅助工具区，右侧为剪藏内容画布与详情卡片

界面方向参考了 `mymind` 官方产品表达中强调的“私密、安静、去工具感、卡片化内容组织”思路：

- 柔和暖色背景与轻材质卡片
- 平台分区优先于密集表格
- 结果卡片化，降低扫描负担
- 统一按钮与胶囊样式，减少交互不确定性

## 交互补完说明

这一阶段主要补的是“能看”之外真正影响信息整理效率的部分：

- 重复添加检测：
  对 `http/https` 链接做精确重复检查；若已存在，弹窗提示用户选择取消，或继续添加重复条目。
- 详情卡片可编辑：
  `summary` 不再只是只读摘要，而是和 `category / tags / note / status` 一样可直接编辑并保存。
- 未保存退出保护：
  详情卡片存在未保存改动时，点击右上角关闭会弹窗提醒，避免误关导致内容丢失。
- 左划动作：
  剪藏行支持左划，直接执行“删除”和“置顶 / 取消置顶”；同时保留右键菜单作为补充入口。
- Trash 生命周期：
  进入 trash 的条目会记录进入时间，超过 30 天会在后续刷新和启动时自动清理。
- 保存链路修复：
  `Save Clip` 现在会一并保存可编辑的 `summary`，并且在条目因筛选条件变化暂时离开当前列表时，详情卡片仍能正确读取数据库中的最新状态。

## 默认分类样例

应用启动时会自动检查本地库，如果对应 URL 不存在，就补齐一组默认样例数据。当前每个平台分类内置 3 个真实网址，共 18 条。

分类覆盖如下：

- `X帖子`: `x.com/OpenAI`、`x.com/TwitterDev`、`x.com/github`
- `小红书`: 首页、`/explore`、`/about`
- `微信公众号`: `mp.weixin.qq.com` 首页、后台首页、真实文章链接
- `抖音`: 首页、`/discover`、`/hot`
- `YouTube`: `@OpenAI`、`@GoogleDevelopers`、`@TED`
- `其余网页`: `openai.com`、`developer.apple.com`、`wikipedia.org`

这些样例的目标不是“伪造演示数据”，而是让分类模块、卡片布局、检索路径和详情面板在首次运行时就有足够真实的内容密度。

## AI 智能分类与查询逻辑

这一部分是当前实现里最关键的链路。

### 1. 采集输入

应用支持两种主输入：

- 当前网页采集
- 剪贴板文本采集

如果浏览器扩展提交了更完整的正文 / 选中文本，桌面端优先使用 richer payload；如果只拿到了 URL，桌面端会按配置尝试拉取公开网页 HTML，并提取纯文本摘要。

对应代码：

- `apps/macos/Sources/CosmogonyCore/AppModel.swift`
- `apps/macos/Sources/CosmogonyCore/CaptureServices.swift`

### 2. 平台识别

系统首先通过 URL host 做第一层稳定分类：

- `x.com` / `twitter.com` -> `X帖子`
- `xiaohongshu.com` -> `小红书`
- `mp.weixin.qq.com` -> `微信公众号`
- `douyin.com` / `iesdouyin.com` -> `抖音`
- `youtube.com` / `youtu.be` -> `YouTube`
- 其余域名 -> `其余网页`

对应代码：

- `apps/macos/Sources/CosmogonyCore/Support.swift`
- `PlatformClassifier.bucket(for:)`

### 3. 智能分类建议

平台分类之后，系统会结合人工维护的 `CategoryRule` 规则做第二层语义归类：

- 规则包含 `canonical` 主分类与 `aliases` 别名集合
- 在保存 clip 时，系统会用 `domain + platform title` 与别名做匹配
- 命中规则就使用规则分类；未命中则回退到平台标题

这使得分类既可解释，又不会完全依赖黑盒模型。

对应代码：

- `apps/macos/Sources/CosmogonyCore/AppModel.swift`
- `categorySuggestion(for:domain:)`
- `apps/macos/Sources/CosmogonyCore/Support.swift`
- `CategoryRule`

### 4. 搜索索引生成

每个 `ClipItem` 在写入数据库前都会生成 `searchText`，把以下字段合并成统一搜索语料：

- `title`
- `domain`
- `excerpt`
- `content`
- `category`
- `tags`
- `note`

这样做的好处是：

- 搜索逻辑简单稳定
- 本地检索无外部依赖
- 后续扩展 embedding 检索时仍可保留 lexical fallback

对应代码：

- `apps/macos/Sources/CosmogonyCore/Support.swift`
- `ClipItem.composeSearchText(...)`

### 5. 查询与排序

当前查询逻辑采用“词法优先、语义预留”的分层实现：

- 标题命中加权最高
- 域名、分类、标签次之
- 查询拆词后再做全文 token 命中累计
- 分数相同时按 `capturedAt` 倒序

如果系统检测到默认 embedding profile 已配置且可用，会把搜索模式切到 `embedding-ready`，为后续向量召回保留扩展入口；如果没有，则稳定回退到本地 lexical/taxonomy 搜索。

对应代码：

- `apps/macos/Sources/CosmogonyCore/Persistence.swift`
- `fetchClips(...)`
- `apps/macos/Sources/CosmogonyCore/Support.swift`
- `SearchScorer`

### 6. 为什么这样实现

当前版本没有把“是否接入大模型”作为唯一前提，而是采用下面这条更稳的链路：

1. 先用平台识别保证基础可用
2. 再用人工分类规则保证可控语义
3. 再用摘要与全文索引保证搜索体验
4. 最后通过 Provider Profile 保留 AI / embedding 升级路径

这样即使用户没有配置任何外部模型，分类与查询依然成立；配置好 Provider 后，再继续向真正的语义搜索演进。

## 本地开发

### macOS app

```bash
cd apps/macos
swift build
swift run CosmogonyChecks
```

### Xcode 工程

仓库已包含 Xcode 工程：

- `apps/macos/Cosmogony.xcodeproj`

如果需要重新生成：

```bash
xcodegen generate --spec apps/macos/project.yml
```

### 构建本地 `.app`

```bash
bash apps/macos/scripts/package_app.sh
open apps/macos/dist/Cosmogony.app
```

产物：

- `apps/macos/dist/Cosmogony.app`
- `apps/macos/dist/Cosmogony.zip`

### Chromium Companion Extension

1. 打开 `chrome://extensions`
2. 开启 Developer mode
3. Load unpacked `extensions/chromium`

Bridge 接口：

- `GET /v1/health`
- `POST /v1/handshake`
- `POST /v1/captures/page`
- `POST /v1/captures/clipboard`

### Python 辅助脚本

```bash
cd tools/python
uv venv ../../.venv
uv pip install --python ../../.venv/bin/python -e .
python legacy_export_preview.py /path/to/musemark-export.json
```

## Git 远程仓库

当前远程仓库：

`git@github.com:v6582374-netizen/Cosmogony.git`
