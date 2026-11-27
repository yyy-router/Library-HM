# CI/CD 与代码门禁

关联 [Issue #4](https://github.com/yyy-router/Library-HM/issues/4)。

## 自动门禁

工作流统一为 `.github/workflows/ci.yml`，包含两个并行检查：

- **Quality Gate**：工程与资源检查、分层检查、文件检查、纯逻辑类型检查和回归测试。
- **HarmonyOS Gate**：安装鸿蒙依赖、官方 Code Linter 检查、Hvigor 原生编译和产物保存。

触发条件：所有分支推送、面向 `main` 的 PR，以及手动执行。PR 新建、代码更新、重新打开、标题或描述修改、退出草稿状态时均重新检查。没有按文件路径跳过任务，也不允许忽略检查失败。

两个检查均运行在 GitHub 托管的 `ubuntu-24.04` 上，不需要自托管 runner、华为账号或签名密钥。PR 检查默认检出 GitHub 生成的合并版本；工作流使用只读 token，不保留 Git 检出凭据。

## 基础检查范围

| 检查 | 能发现的问题 |
| --- | --- |
| 工程配置 | JSON/JSON5 语法错误、模块名称不一致、缺失默认产品、Ability 入口或页面文件 |
| 资源与导入引用 | 缺失字符串/颜色/图标/页面配置、失效的相对导入、Windows 下容易遗漏的路径大小写错误 |
| 分层依赖 | 业务模型依赖 UI/SDK、数据层反向依赖页面、页面绕过仓库接口直接创建数据实现、ViewModel 直接引用 SDK |
| 文件与基础格式 | 忽略文件被强制纳入版本控制、子目录中的签名配置、大小写扩展名的私钥与证书、部分明显硬编码密钥、尾随空白、冲突标记、无效 UTF-8 |
| 工作流配置与规则 | YAML 错误、可变 Action 标签、过大的 token 写权限、缺少超时、跳过原生检查、错误的必需检查名称或来源应用 |
| PR 规范 | 中文 Conventional Commits 标题、描述中的 `Closes #<issue>`，仅在 PR 事件检查 |
| 纯逻辑类型检查 | 业务模型、仓库、演示实现、ViewModel 的严格 TypeScript 类型错误 |
| 逻辑回归 | 搜索过滤、清空后的迟到响应与错误丢弃、新搜索或登录的忙碌状态隔离、书架去重、演示导入、历史恢复、下载/重试、未下载阅读拦截、离线本地文件、登录密码清理 |
| 网络与会话回归 | 查询/表单/JSON、状态码、错误脱敏、取消与句柄释放、真实仓库装配、鉴权与业务失败、会话恢复/删除、ASSET SDK 契约；稀疏书目、匿名热门、封面无鉴权/缓存/去重/失败重试与体积限制 |
| 主题资源回归 | 亮暗资源名称对应、普通/次级/弱化文字、选中和未选中导航、按钮的实际配色对比度，图标深色版本；不代替设备渲染验证 |
| 门禁回归 | 在临时副本中故意破坏资源、页面、路径大小写、依赖方向、工作流、合并规则和 PR 信息；资源移动未暂存时检查索引中的旧路径与工作区新资源，保留凭证扫描 |
| 原生脚本回归 | 模拟依赖安装失败、Lint 工具错误、错误报告、报告缺失或损坏、编译失败、HAP 缺失或为空，验证不能误报成功 |
| SDK 完整性回归 | 模拟损坏的 SDK 下载，验证 SHA-256 不匹配时不会解压或执行工具 |

纯逻辑检查将选中的 `.ets` 文件复制到被忽略的 `.local/ci/logic/`，由 TypeScript 编译器检查并生成隔离测试模块。测试中的 `@Observed` 是无行为的替身；它不验证 ArkUI 观察机制、UI 语法、设备能力或真实渲染，也不能代替鸿蒙原生编译。凭证检查只是基础规则扫描，不是完整的泄露检测服务。

`platform/` 与 `app/platform/` 含系统 SDK，不进入纯逻辑编译。`tests/network.test.cjs` 编译实际适配器源码并注入 SDK 替身，检查参数、取消、资源释放和安全存储调用；官方 Lint 与原生编译仍检查完整工程。替身不证明真实 NetworkKit/ASSET 已在设备运行。

辅助工具使用 Node.js 24，依赖版本由 `package-lock.json` 固定，工作流使用 `npm ci --ignore-scripts`。官方 Actions 固定到完整提交 SHA。原生脚本回归使用 PowerShell 中的工具替身，只验证编排和失败处理，不代表 SDK 已实际运行。

## 官方检查与原生编译

`scripts/ci/setup-harmony.sh` 从华为云公开仓库下载固定版本的原始工具包，先核对 SHA-256，再解压执行，不使用第三方重打包 SDK：

| 项目 | 固定值 |
| --- | --- |
| Command Line Tools | `5.1.0.840`，Linux x86_64 |
| 安装包 | `https://repo.huaweicloud.com/harmonyos/ohpm/5.1.0/commandline-tools-linux-x64-5.1.0.840.zip` |
| SHA-256 | `1dcefa4741dc289277560b2802040e0c45b433898d8db453d711d5376e0478f1` |
| 工具包内 SDK | HarmonyOS `5.1.0.125`，API 18 |
| Code Linter | `5.1.140` |
| Java | Temurin 17 |

该 SDK 用于 CI 编译，应用的兼容与目标版本仍由 `build-profile.json5` 指定为 HarmonyOS 5.0.0（API 12）。原生任务使用工具包配套的 Node.js，与辅助检查的 Node.js 24 分开。

`scripts/ci/build-harmony.ps1` 分阶段执行：

1. **Install**：在工程根目录及 `entry` 中执行 `ohpm install --all`；失败立即停止。
2. **Lint**：按根目录 `code-linter.json5` 检查全部应用 ArkTS 源码，启用通用、性能和安全推荐规则，输出 JSON 报告。当前固定版本没有新版 `--exit-on` 选项，因此脚本解析报告：error 阻止通过，warn/suggestion 保留在报告中；工具错误、无报告、无效报告和未知告警级别同样失败。每轮检查先移除旧报告，防止沿用旧结果。
3. **Build**：运行 `hvigorw clean --no-daemon`，再编译 `entry@default` 的 debug HAP。依赖或编译失败、没有非空的未签名 HAP 均返回失败。

原生门禁最多运行 40 分钟。SDK 安装包约 2 GB，下载超时或校验失败会直接导致门禁失败，不会跳过检查。当前不缓存解压后的 SDK。

产物保留 7 天：

- `.local/ci/reports/codelinter.json`：即使后续检查失败，也尝试保存已经产生的报告。
- `entry/build/default/outputs/default/*-unsigned.hap`：仅原生检查成功后上传；缺失时失败。

产物名包含运行 ID 和重试次数，以区分重复运行。本阶段不签名、不安装到设备、不发布应用商店。

## 本地执行

使用 Node.js 24–26，在项目根目录执行：

```powershell
npm ci --ignore-scripts --no-audit --no-fund
npm run ci
```

也可以分别执行 `npm run check`、`npm run build:logic` 和 `npm test`。Windows 如果限制运行 `npm.ps1`，将命令中的 `npm` 替换为 `npm.cmd`。

根目录的 `package.json` 只管理 CI 开发工具，鸿蒙应用仍使用 `oh-package.json5` 和 DevEco/Hvigor 工具链。

本机已配置配套 HarmonyOS SDK、Node.js、JDK、`ohpm`、`hvigorw` 和 `codelinter` 后，可在 PowerShell 中执行原生检查：

```powershell
./scripts/ci/build-harmony.ps1
```

也可分别指定 `-Task Install`、`-Task Lint`、`-Task Build`。Lint 和 Build 单独执行前先完成 Install。Windows 支持 Windows PowerShell 5.1 或 PowerShell 7；Linux 使用 PowerShell 7。

## 本地调试签名

`build-profile.json5` 是共享构建配置，必须纳入 Git，但不能包含签名密码、证书路径和密钥材料。密钥文件与本地签名配置均被忽略，不能通过 `skip-worktree` 隐藏共享文件中的凭证。

当前 DevEco Studio 26.0.0 会将自动签名配置写入共享文件。首次配置或更新签名后，按以下步骤隔离：

1. 在 IDE 的 `File > Project Structure > Project > Signing Configs` 中完成自动签名，确认目标 product 已关联对应方案。
2. 执行 `npm run signing:import`，将签名方案与产品关联移入被忽略的 `.local/signing.json`，同时清理共享文件中的签名材料。该命令使用已安装的 CI 开发工具，不上传任何内容，也不生成新证书。
3. 重新执行 IDE Run 或原生构建。`hvigorfile.ts` 使用官方构建上下文接口，在内存中加载本地签名；不会将材料写回共享配置。

导入命令拒绝覆盖已有的 `.local/signing.json`。更新证书前，先将旧文件**移动或重命名**到 `.local/` 内的其他文件名，确认原路径已空出，再导入新的配置；仅复制备份不能空出原路径。普通构建无需反复生成或导入证书。

导入在同目录的独占临时文件中写入清理后的构建配置，写完并关闭后才替换共享文件。写入或替换失败时保留原共享文件，并尝试清理本轮新建的本地签名和临时文件，以便重试；已有本地签名文件不会被覆盖或删除。

没有本地签名文件时，构建继续生成未签名 HAP，适用于 CI 和编译验证；真机运行需要配置本地签名。不要将本地签名文件或密码添加到 GitHub Actions。

工程门禁会拒绝共享构建配置中的签名方案，文件扫描同时拒绝签名材料与独立签名配置文件，即使它们被强行加入 Git 跟踪。报错不输出密码值。

实现依据：[华为 Hvigor 动态签名配置示例](https://developer.huawei.com/consumer/en/doc/HarmonyOS-Guides/ide-hvigor-config-ohos-sample/)。华为在 [26.0.1 版本说明](https://developer.huawei.com/consumer/cn/doc/harmonyos-releases/deveco-studio-new-features-2601/) 中新增了独立签名配置文件；当前实现兼容本机 26.0.0，不要求升级 IDE。

## 将检查设置为合并门禁

规则源文件为 `.github/rulesets/main.json`，要求：

- 通过 PR 合并到 `main`，解决全部评审讨论。
- `Quality Gate` 和 `HarmonyOS Gate` 都必须由 GitHub Actions 应用产生并通过。
- 合并前分支必须与主分支保持最新。
- 禁止删除主分支或强制推送，无绕过名单。

2026-11-25，已通过 GitHub API 创建并回读确认这组规则处于 `active` 状态：[Library-HM main quality gates](https://github.com/yyy-router/Library-HM/rules/28044300)，规则 ID 为 `28044300`。两个必需检查均绑定 GitHub Actions 应用（ID `15368`）。

本仓库仅配置流程约束，不强制额外的审批人数，以支持仓库所有者自行提交 PR；这不取消 `AGENTS.md` 中推送前的人工评审要求。

具有仓库管理权限时，可以通过 GitHub Rulesets 导入该 JSON，或调用 REST API 创建规则。更新现有规则时使用对应规则 ID 的更新接口，避免重复创建。

规则启用后，即使工作流尚未推送，PR 也必须等待两个状态检查；应在人工评审通过并明确要求推送后，再推送本分支并核对远端执行结果。创建 PR 不代表授权合并。

## 验证状态与边界

2026-11-27，在本地 Windows 环境实际执行：

| 命令或阶段 | 结果 |
| --- | --- |
| `npm run ci` | 工程、资源、分层、文件及工作流检查通过；35 个纯逻辑源文件类型检查通过；83 项测试全部通过 |
| `scripts/run-harmony.local.ps1 -Task Lint` | 使用根目录源码执行官方 Code Linter，0 个 error、4 个 warn、1 个 suggestion |
| `.local/ci/run-local-signing.mjs`（已忽略） | 使用本地已安装依赖运行 Hvigor 原生编译与签名，`BUILD SUCCESSFUL`；本轮未执行 clean 或重新安装依赖 |
| 原生 HAP | 生成非空的未签名与调试签名 HAP，位于 `entry/build/default/outputs/default/` |
| 平板真机横屏 | 2800×1840 截图与 UI 树复核个人推荐、20 条“机器学习”搜索结果、真实封面和滚动；卡片原始边界未跨出所属列 |

本次使用 DevEco Studio 26 自带的 Windows 工具：Node.js `24.14.1`、ohpm `26.0.0.630`、Hvigor `6.26.9`、Code Linter `6.0.240`、JBR `25.0.2`、SDK `26.0.0.105`（API 26）。本机私有脚本 `scripts/run-harmony.local.ps1` 已被 Git 忽略，仅临时设置进程环境，执行结束后恢复。

四条 Lint 警告建议简单组件优先使用 `@Builder`，另有一条 WaterFlow 预加载建议；按当前策略均不阻止通过。本轮已覆盖安装调试包并验证当前平板横屏，竖屏和完整亮暗切换尚未验收。下载成功和本地导入的逻辑测试使用文件适配器替身，只证明状态契约，不代表已下载、落盘或渲染真实图书。

评审修复见 Issue #11。签名导入回归只操作临时目录中的合成配置，覆盖本地签名写入、临时文件写入和替换失败：原共享文件逐字节保留，清理本轮新建文件后可重试；临时路径冲突不删除原有文件。真实本地签名不用于故障注入。

PR #10 已合并，其远端双门禁通过；网络层属于后续工作，不能沿用旧提交的远端结果。

Issue #12 的网络改动尚未推送。本机匿名请求 `https://z-lib.gd/eapi/info`、`https://z-lib.gl/eapi/info`、`https://article.sk/eapi/info` 均得到 HTTP 200 且解析出 JSON `success: 1`；服务响应的 Content-Type 不保证写成 JSON，不能仅依赖该头判断。此检查没有账户凭证，也不是原生设备请求；真实登录、用户搜索、推荐与 ASSET 跨启动恢复仍需在设备上验收。

Issue #13 匿名热门与封面验证：`https://z-lib.gd/eapi/book/most-popular` 返回 HTTP 200、`success: 1`、100 条书目，首条字段没有 `extension`；`/eapi/user/book/recommended` 无凭证时返回 HTTP 403、`success: 0`。抽取一张真实封面以无鉴权客户端读取，得到 HTTP 200、JPEG 魔数与 10185 字节正文。匿名探测不代表个人推荐验证，后者已按下段在真实登录态设备上检查。回归覆盖登录/退出与迟到列表响应竞争，竖屏验收仍未完成。

后续连接设备复核发现：FlowItem 每列约 605px，而卡片的百分比宽度被解析为整个 WaterFlow 的 2576px，导致相邻卡片覆盖封面与文本。改为读取实际内容区并传入明确列宽后，首页和搜索的截图恢复正常，滚动后的 UI 树分别检查 8 张卡片，原始边界均位于各自列内。设备显示真实个人推荐，搜索得到 20 条且格式可显示 PDF/EPUB；缺失格式字段的卡片按用户要求隐藏标签，简介实体转义也已处理。截图和 UI 树保留在被忽略的 `.local/ci/screenshots/`，不携带到 Git；未读取或输出会话密钥。

2026-11-25，[PR #5](https://github.com/yyy-router/Library-HM/pull/5) 在提交 `22b81af` 上首次完成了 [GitHub Actions 验证](https://github.com/yyy-router/Library-HM/actions/runs/45545986654)：`Quality Gate` 和 `HarmonyOS Gate` 均通过。Linux runner 成功安装并校验 Command Line Tools `5.1.0.840`，Code Linter 为 0 个 error、0 个 warn，Hvigor 原生编译成功，Lint 报告和未签名 HAP 两份 artifact 均已上传。

仍需区分：

- 工作流 Actionlint 检查此前已在本地通过。
- 已查询并核对华为云发布的 SDK SHA-256，以及固定工具包中的 SDK 元数据与 Code Linter 命令参数、JSON 报告结构。
- 远端执行结果以对应 PR 的 `Quality Gate` 和 `HarmonyOS Gate` 状态为准。
- 本地通过的是 Windows DevEco 26 工具链；GitHub 使用固定的 Linux Command Line Tools `5.1.0.840`，不能用本地结果代替该工具链的远端验证。
- 当前不包含模拟器/真机 UI 测试、横竖屏自动验证或签名发布；后续接入真实阅读能力和发布流程时补充。

参考：[华为命令行流水线说明](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-command-line-building-app/)、[Code Linter 配置](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-code-linter/)、[华为云工具下载目录](https://repo.huaweicloud.com/harmonyos/ohpm/5.1.0/)、[GitHub Rulesets API](https://docs.github.com/en/rest/repos/rules)。
