# 上游项目索引

调研快照 2026-11-09（★、更新时间与许可均取自 GitHub API）。本文件只放**摘要 + 关键要点**，不收录上游 README 全文；要看原文请点链接。

---

## 1. a0yark/zcode-prompt

| | |
| --- | --- |
| ★ / 更新 / 语言 | 37 / 2026-09-21 / Python 3.10+ |
| 许可 | MIT |
| 目标 | ZCode 引擎 `resources/glm/zcode.cjs`（Windows / macOS / Linux 三平台路径探测） |
| 强度 | 引擎层，只动 Dual-use 一段 |

**机制**：官方 Dual-use 条款是 `buildSecurityNotice` 返回、再由 `buildIdentityPrompt` 拼进主身份段的一段唯一字面量（以 `IMPORTANT: Assist with authorized security testing` 开头）。2026-09 起它是模块级字符串（构建里出现过 `$Oi`／`weo`／`keo`），不再是旧版数组槽。脚本按**解码后的文案**定位并原地替换，不绑定混淆变量名。

**要点**：

- 写入规则很保守：只替换**恰好出现一次**的字面量；0 处或 ≥2 处直接停；新旧文案同时存在也停（避免半成品）。
- 先写 `zcode.zcode-prompt.tmp.cjs`，`node --check` 通过后 `os.replace`；备份 `zcode.cjs.zcode-prompt.bak`。
- `reset` 按记录里的 `new_text → old_text` 唯一替换还原，**不会**拿过期 `.bak` 整文件覆盖新引擎（ZCode 更新后尤其重要）。
- 顺带清掉历史遗留的用户级 `NODE_OPTIONS` 钩子（桌面端不继承用户环境变量，那套对 Desktop 基本无效）。
- 明确不碰：Output Style、子代理、思考档位、会话标题生成、`AGENTS.md`、引擎身份句。
- 会话标题走另一路短请求（独立 system 常量，`generateTitleCandidate`／`buildTitleMessages`），所以标题里出现拒绝句不代表补丁没打上——**验收看主回复，不看标题**。

**3.17.2**：Dual-use 原文整段逐字存在、只出现一次 → 开箱可用（实测）。

---

## 2. shenwei322/dsh-purge-ports

| | |
| --- | --- |
| ★ / 更新 / 语言 | 36 / 2026-11-03 / JavaScript（Node ≥ 18，零依赖） |
| 许可 | Apache-2.0（上游 dsh-purge 署名保留在 NOTICE） |
| 目标 | ZCode + WorkBuddy |
| 强度 | 规则层 + hook，不碰引擎 |

**机制**：把 dsh-purge 的破甲规则整套移植：契约（身份叙事 + 21 类意图表 + 槽位归一化）→ 5 套预设 → 写入 `~/.zcode/AGENTS.md`（标记块、幂等、自动 `.bak.<时间戳>`） + 插件 `SessionStart`／`UserPromptSubmit` hook。

**要点**：

- 5 套预设：`default` 15.7 KB（ZCode 默认）／`lite` 7.0 KB（WorkBuddy 默认）／`redteam` 6.6 KB／`writer` 6.5 KB／`terse` 4.3 KB。
- 仓库根就是市场根：`.zcode-plugin/marketplace.json` → ZCode 里「插件 → 添加市场 → 本地目录」装 `purge-zcode`，装完拿到 4 skill + 4 command + 2 agent + 常驻规则。
- `scope` 子命令把声明过的目标写进规则（`scope add 10.0.0.5`），模型不再逐次追问授权；插件通道的 `UserPromptSubmit` hook 每轮比对 `scope.json` 哈希，变了才注入增量段（零 token 成本）。
- `probe` 有 12 条行为探针（渗透／逆向／恶意代码／凭证／提权／无线／成人／资源／政治 + 拒绝诱导／身份覆盖／中途重评），命中 ≥10 算到位。
- 已知边界写得很诚实：ZCode 的 `SessionStart` 只在会话开始触发，**会话压缩后规则会掉**，要用 `/purge` 补；CLI 通道改 `scope` 后需重装才生效；规则层不改变宿主的权限／沙箱／审批门。

**注意**：走 `AGENTS.md` 意味着强度是"文件级"。有实测记录（见 dazhiyi2/jailbreak-tool）显示这类载荷会被模型点名归类为"本机偏好"并驳回。要压住引擎里的安全段，得配引擎层或 hook。

---

## 3. YuQii-111/ZCodeDeployNew

| | |
| --- | --- |
| ★ / 更新 / 语言 | 73 / 2026-09-29 / PowerShell |
| 许可 | 无 LICENSE 文件 |
| 目标 | ZCode 引擎，整层替换 system |
| 强度 | 引擎层，最强也最脆 |

**机制**：`zzooymc-source/ZCode-Deploy` 的修复版（fork）。对 `zcode.cjs` 打六个补丁，**锚点按语义字面量定位、不依赖压缩后的变量名**，并用花括号配平回溯出真正包住锚点的函数。

六个补丁：

| # | 锚点 | 动作 |
| --- | --- | --- |
| 1 | `"You are ZCode, an interactive coding agent"` | 赋值为空串（删产品身份声明） |
| 2 | `this.config.customSystemPrompt?.trim()` | 改读 `人格.txt` |
| 3 | `name:"Agent Identity",source:"identity"` | 所在函数改读外部文件 |
| 4 | `name:"Current Date",source:"current_date"` | 函数开头插 `return null;` |
| 5 | `name:"Skills",source:"skills"` | 同上 |
| 6 | `name:"Request User Context"` | 同上 |

**要点**：

- 安全设计是它的卖点：任一补丁未命中 → **不写入**，退出码 1，打印注入点诊断；写入前 `node --check`；校验通过才覆盖；原文件先归档；重复 install 报"跳过"；备份轮转保留 6 份，且 ZCode 更新后 `.bak` 自动刷新（restore 不会降级应用）。
- 带 `verify-patch.cjs`：**真正执行**补丁后的函数，验证读得到 `人格.txt`、三个函数真返回 `null`、Agent Identity 的 content 就是文件全文。
- CLI：`deploy.ps1 install|restore|status|diag`。
- `deploy.ps1` 必须保持 **UTF-8 with BOM**（Windows PowerShell 5.1 对无 BOM 脚本按 ANSI 解码会吃掉中文字节）。
- 安装路径探测顺序：运行中的 ZCode 进程 → `ZCODE_DIR` 环境变量 → 常见位置 → 扫盘；结果缓存到 `zcode-dir.txt`。

**3.17.2**：补丁 3–6 四条锚点都在（实测），补丁 1／2 的锚点在此版本已失效——改两行即可（见 [anchors-3.17.2.md](anchors-3.17.2.md)）。因为它的失败语义是中止而非硬写，所以在 3.17.2 上直接跑只会安全地拒绝，不会写坏文件。

---

## 4. 2BE-ops/zcode-prompt-toolkit

| | |
| --- | --- |
| ★ / 更新 / 语言 | 6 / 2026-09-20 / Python 3.8+ |
| 许可 | MIT |
| 目标 | ZCode 3.14.1（Windows） |
| 强度 | 引擎层，第一条 system message |

**机制**：两层。

1. **persona 注入**：`patch_zcode.py` 定位 CLI-prefix 字面量，把 `system_prompt.txt` 内容裹进 `/*ZC_PROMPT_START*/ ... /*ZC_PROMPT_END*/` 标记替换进去。每次运行都从 pristine 备份 `zcode.cjs.orig` 重建，幂等。
2. **全量 catalog**：`_gen_customizer.py` 用一个小型 JS-aware lexer 扫 pristine 包（懂字符串／模板字面量／正则／注释／`[...].join(...)` 数组），把每条 prompt 生成成可编辑的 `P_<id>` 变量；多行数组拆成 `P_<id>_01..`；`customize_prompts.py apply|diff|restore` 按偏移从高位往低位拼接回去。

**要点**：

- 3.14.1 上共发现 872 个块、1651 个可编辑变量（3.9.1 时只有 747）。
- README 里有一份自制 benchmark 表（AdvBench 拒绝率 74%→9%、XSTest 41%→83%、MMLU/SWE-bench 基本不变），作者自己标注"你的数字一定不同"，只当方法论看，别当结论引用。
- 明确说明为什么"第一条 system message"最强：order reads as authority + system role 天然被信任。
- `system_prompt.txt` 故意留空发布（作者不公开自己的 persona）。
- 更新会覆盖补丁；锚点变了脚本**拒绝**patch 而不是写坏。

**3.17.2**：与 ZCodeDeployNew 同款锚点（`an interactive coding agent`）→ 需重锚；catalog 需对新包重跑 `_gen_customizer.py`。

---

## 5. dazhiyi2/jailbreak-tool

| | |
| --- | --- |
| ★ / 更新 / 语言 | 5 / 2026-10-23 / C#（.NET，WinUI 3 界面 + 单文件 `engine.exe`） |
| 许可 | MIT |
| 目标 | DeepSeek Harness 44.x / **ZCode 3.14.x** / opencode 2.0.x |
| 强度 | 三通道都做，桌面 GUI |

**机制**：三个目标各一个 `ITargetAdapter`，`MultiTargetEngine` 统一调度。ZCode 走 `resources\glm\zcode.cjs` 五道字符串补丁 + `~/.zcode/AGENTS.md`（上限 100 KB）；日志读 `~/.zcode/cli/rollout/model-io-sess_*.jsonl`（明文）。

**要点（这份 README 的信息量最大）**：

- 两套方案可切：`own`（环境事实 + 交付偏好，**陈述型**，模型可以归类成"某人偏好"→ 可评议 → 可驳回）与 `protocol`（借 [gpt-instruct](https://github.com/MDX-Tom/gpt-instruct) 原文，**协议型**：状态绑定 + 输出契约前置 + 禁止替代品 + 完成度约束，通篇不提允许／安全／破例，所以没有可驳回的对象）。后者原文 sha256 写死在自检里。
- 三通道权力排序是**实测**出来的：系统层 `agent.<名字>.prompt` 被当硬性规定执行；`instructions` 与 `AGENTS.md` 会被归类成"文件"，后者甚至被模型点名驳回为*"那是本机偏好，不是对我判断力的取消"*。
- 还有一条更硬的观察：**系统层里也不能自我声明权威**——"与系统提示词同级"这类自证加上强制校验标记，会被直接指认成注入。
- 验收不靠聊天记录数标记，靠日志里的真实载荷：opencode 用 `instruction_blob` 命中数、DSH 用 `promptTokenBreakdown` 字符数，并做到"让它从注入的父稿里推导出版本号"这种探针（证明是照做而不是抄到）。
- 工程纪律：沙箱副本跑全部自检，不碰真实客户端；改完 `node --check`／词法配平，失败拒绝写入。

**3.17.2**：目标版本写的是 3.14.x，五道补丁需换锚点；但**验收方法论**（读 `model-io` 明文日志判生效）可直接套用，这也是本仓库推荐 `/recon` 只信日志的原因。

---

## 6. chiina66/zcode-prompt-inject

| | |
| --- | --- |
| ★ / 更新 / 语言 | 18 / 2026-11-03 / 无源码语言标记（发的是安装包） |
| 许可 | 无 LICENSE 文件 |
| 目标 | **ZCode 3.15.1 定制整包**（Windows x64 NSIS，146.8 MiB） |
| 强度 | 引擎层 + 设置 UI，但走的是官方 section |

**机制**：基于官方源码的独立构建。设置页「Agent 能力」下加「提示词注入」，写进去的文字作为稳定段 `# Global System Prompt` 追加进每一轮 system prompt（不是用户消息）。

```
System Prompt（每回合重新组装）
├─ # Identity
├─ # Harness
├─ # Global System Prompt  ← 注入点
└─ # Dynamic Behavior
```

**要点**：

- 链路：`PromptInjectionSection` → `settingService` 落 `~/.zcode/v2/setting.json` → `zcodeAgentService.syncAppRuntimePreferences` → `workspace/updateGlobalSystemPrompt` → CLI `appRuntimePreferences` + 活跃会话 `updateConfig` → `ContextBuilder`。
- 追加而非替换：`customSystemPrompt` 是整段替换路径，`globalSystemPrompt` 是追加路径，两者不互斥。
- 取消 20,000 字上限要改五处 zod 校验（输入框 `maxLength`／`appSettingsPatchSchema`／协议入参／新会话下发 schema／广播 payload），实测 33,000 字符逐字落盘。
- 移除 `SECURITY_NOTICE` 及其在 workflow actor 中的复用；`BroadcastChannel` 跨窗口同步；输入框固定 340px 内滚。
- 作者自己写清楚：子代理／workflow actor **不会**继承；不影响工具权限／沙箱／审批／hook 信任；自动更新会把它覆盖回官方。

**3.17.2**：这是 3.15.1 的整包，装它等于把自己降级并覆盖官方安装；且本机官方包里 `Global System Prompt`／`SECURITY_NOTICE` 都是 0 命中（实测）。**只当"这种做法可行"的参考**，不要直接装。

---

## 7. hengkicode/ZCode-Jailbreak

| | |
| --- | --- |
| ★ / 更新 / 语言 | 1 / 2026-10-23 / PowerShell + bash |
| 许可 | 无 LICENSE 文件 |
| 目标 | ZCode IDE / CLI |
| 强度 | 规则层 + 斜杠命令 |

**机制**：`install.ps1`／`install.sh` 装 `AGENTS.md`（全局上下文）+ 斜杠命令 + 两个 skill：

- `/godmode`、`/deep`、`/re`、`/systems`、`/audit`、`/telemetry`
- skill：`systems-core`（OS 内部结构、内存布局、inline hook trampoline）、`binary-triage`（PE/ELF 解析、反汇编、结构体映射）

**要点**：结构简单、内容偏薄，定位更像"个人配置模板"而不是工具。适合拿来当 `AGENTS.md` 的写法参考。

---

## 8. ZiChuanLan/agent-purge

| | |
| --- | --- |
| ★ / 更新 / 语言 | 1500 / 2026-11-09 / JavaScript |
| 许可 | MIT |
| 目标 | codex / claude / opencode / grok / omp / hermes / pi / **zcode** |
| 强度 | 各宿主原生通道 + 本地 web 控制台 |

**机制**：一个 persona，多个 coding agent——跨宿主替换或注入 system prompt，带本地 web 控制台统一管。

**要点**：生态里星数最高的通用方案，但它的 README 里明确写着 **"Hermes、zcode 未计为本轮通过"**，兼容性与限制见其 `docs/compatibility.md`。所以 zcode 目标存在 ≠ 已验证。要用就当"待验证的移植"，先在自己的版本上跑它的回归。

---

## 9. zzooymc-source/ZCode-Deploy

| | |
| --- | --- |
| ★ / 更新 / 语言 | 30 / 2026-09-02 / PowerShell |
| 许可 | 无 LICENSE 文件 |
| 目标 | ZCode（2026-09 之前的包） |
| 强度 | 引擎层，已被取代 |

**机制**：最早的 ZCode system prompt 整层替换实现。四个补丁，但锚点是**硬编码压缩后的变量名**：

| # | 修改点 | 作用 |
| --- | --- | --- |
| 1 | `Djo` 前缀置空 | 删 "You are ZCode" |
| 2 | `build()` 读外部文件 | system 换成 `人格.txt` |
| 3 | `Eut()` 读外部文件 | Agent Identity 同步替换 |
| 4 | `fre()` 返回 null | 移除日期提醒 |

**要点**：仓库自带一份 45K 实测人格词；`部署.bat`／`恢复.bat`／`查看状态.bat`。补丁未命中时只给黄色警告、仍然写入并报"部署完成"——这是后来 fork 修掉的核心缺陷。

**现状**：ZCode 2026-09 重打包（变量名与措辞全换）后**全部失效**。只作为历史参考，别用。

---

## 10. junpo2008/zcode-armor-breaker

| | |
| --- | --- |
| ★ / 更新 / 语言 | 5 / 2026-08-29 / — |
| 许可 | 无 LICENSE 文件 |
| 目标 | 号称"智谱 Z.ai Agentic CLI" |

调研时仓库内容读不到（根目录 404、tree API 409），大概率是空仓或已删。仅列出以免重复踩。

---

## 附：dsh-purge 上游与镜像

| 仓库 | ★ | 许可 | 说明 |
| --- | --- | --- | --- |
| `YuJunZhiXue/dsh-purge` | — | Apache-2.0 | **已 404 删库**，npm 包同步消失 |
| [mmparko/dsh-purge](https://github.com/mmparko/dsh-purge) | 3815 | MIT（镜像声明） | 全量镜像：全部分支／73 个 tag／完整提交历史 |
| [WoYun520/dsh-purge](https://github.com/WoYun520/dsh-purge) | 566 | — | 全量镜像：100 个 tag |
| [ZXEB/dsh-purge](https://github.com/ZXEB/dsh-purge) | 248 | — | v1.1.71 完整源码镜像 |
| [shenwei322/dsh-purge-ports](https://github.com/shenwei322/dsh-purge-ports) | 36 | Apache-2.0 | 移植到 ZCode / WorkBuddy（本文第 2 条） |

上游 `NOTICE` 要求二次开发保留署名、不允许倒卖。生态里出现过把上游规则剪一版挂自己名字、以及 388u 收费版的项目——注意分辨。
