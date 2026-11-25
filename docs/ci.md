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
| 文件与基础格式 | 忽略文件被强制纳入版本控制、常见凭证与签名文件、私钥及部分明显硬编码密钥、尾随空白、冲突标记、无效 UTF-8 |
| 工作流配置与规则 | YAML 错误、可变 Action 标签、过大的 token 写权限、缺少超时、跳过原生检查、错误的必需检查名称或来源应用 |
| PR 规范 | 中文 Conventional Commits 标题、描述中的 `Closes #<issue>`，仅在 PR 事件检查 |
| 纯逻辑类型检查 | 业务模型、仓库、演示实现、ViewModel 的严格 TypeScript 类型错误 |
| 逻辑回归 | 搜索过滤、书架去重、演示导入、阅读历史更新和排序、进度边界与恢复、失败后的状态恢复、登录密码清理 |
| 门禁回归 | 在临时副本中故意破坏资源、页面、路径大小写、依赖方向、工作流、合并规则和 PR 信息，验证检查确实失败 |
| 原生脚本回归 | 模拟依赖安装失败、Lint 工具错误、错误报告、报告缺失或损坏、编译失败、HAP 缺失或为空，验证不能误报成功 |
| SDK 完整性回归 | 模拟损坏的 SDK 下载，验证 SHA-256 不匹配时不会解压或执行工具 |

纯逻辑检查将选中的 `.ets` 文件复制到被忽略的 `.local/ci/logic/`，由 TypeScript 编译器检查并生成隔离测试模块。测试中的 `@Observed` 是无行为的替身；它不验证 ArkUI 观察机制、UI 语法、设备能力或真实渲染，也不能代替鸿蒙原生编译。凭证检查只是基础规则扫描，不是完整的泄露检测服务。

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

2026-11-25，在本地 Windows 环境实际执行：

| 命令或阶段 | 结果 |
| --- | --- |
| `npm.cmd run ci` | 工程、资源、分层、文件及工作流检查通过；15 个纯逻辑源文件类型检查通过；35 项测试全部通过 |
| `scripts/run-harmony.local.ps1` | 通过，依次完成真实依赖安装、官方 Lint、Hvigor clean 和 HAP 编译 |
| 官方 Code Linter | 0 个 error，2 个 warn；报告位于 `.local/ci/reports/codelinter.json` |
| 原生编译 | `BUILD SUCCESSFUL`，产出 `entry/build/default/outputs/default/entry-default-unsigned.hap`，163,185 字节 |

本次使用 DevEco Studio 26 自带的 Windows 工具：Node.js `24.14.1`、ohpm `26.0.0.630`、Hvigor `6.26.9`、Code Linter `6.0.240`、JBR `25.0.2`、SDK `26.0.0.105`（API 26）。本机私有脚本 `scripts/run-harmony.local.ps1` 已被 Git 忽略，仅临时设置进程环境，执行结束后恢复。

两条 Lint 警告来自 `BookItem.ets` 和 `EmptyState.ets` 的 `@performance/avoid-overusing-custom-component-check`，建议简单组件优先使用 `@Builder`。按当前门禁策略，warn 不阻止通过。原生检查首次在受限执行环境下失败；允许官方工具正常访问本机环境后，同一脚本完整运行成功。

仍需区分：

- 工作流 Actionlint 检查此前已在本地通过。
- 已查询并核对华为云发布的 SDK SHA-256，以及固定工具包中的 SDK 元数据与 Code Linter 命令参数、JSON 报告结构。
- 远端执行结果以对应 PR 的 `Quality Gate` 和 `HarmonyOS Gate` 状态为准。
- 本地通过的是 Windows DevEco 26 工具链；GitHub 使用固定的 Linux Command Line Tools `5.1.0.840`，不能用本地结果代替该工具链的远端验证。
- 当前不包含模拟器/真机 UI 测试、横竖屏自动验证或签名发布；后续接入真实阅读能力和发布流程时补充。

参考：[华为命令行流水线说明](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-command-line-building-app/)、[Code Linter 配置](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-code-linter/)、[华为云工具下载目录](https://repo.huaweicloud.com/harmonyos/ohpm/5.1.0/)、[GitHub Rulesets API](https://docs.github.com/en/rest/repos/rules)。
