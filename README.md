# ZCode 破甲生态勘察

GitHub 上给 **ZCode**（智谱 Z.ai 的 agentic coding CLI／桌面端）做提示词层改造的项目调研，附一份针对 **ZCode 3.17.2** 引擎包（`resources/glm/zcode.cjs`）的锚点实测。

调研时间：2026-11。所有结论都标注了取证方式：`实测` 表示在本机装好的 3.17.2 上跑过字符串命中统计，`README` 表示仅来自上游文档，未验证。

## 目录

- [结论先看](#结论先看)
- [项目索引](#项目索引)
- [3.17.2 锚点实测](#3172-锚点实测)
- [落地路线](#落地路线)
- [验收方法](#验收方法)
- [生态备注](#生态备注)
- [仓库结构](#仓库结构)

## 结论先看

ZCode 的提示词不是一整块，分三层，改哪一层决定了抗不抗升级：

| 层 | 载体 | 强度 | 升级后 |
| --- | --- | --- | --- |
| **引擎层** | `zcode.cjs` 里的字符串字面量（身份句、Dual-use 安全边界、各 section 构造函数） | 最高，进 system prompt 本体 | 被覆盖，需重打 |
| **规则层** | `~/.zcode/AGENTS.md`（有效上限 100 KB） | 中，实测会被模型归类成"本机偏好"并可能点名驳回 | 不受影响 |
| **会话钩子层** | 插件 `SessionStart` / `UserPromptSubmit` hook 注入 `additionalContext` | 中，每轮可刷新 | 不受影响，但会话压缩后会掉 |

三个实用判断：

1. **最省事的一刀**是改引擎里的 Dual-use 段落——原文在 3.17.2 上仍然逐字存在、只出现一次，改它不需要碰身份句和任何 section 结构。
2. **整层替换 system prompt** 的项目在 3.17.2 上要改两行锚点（见下），因为它们写的是 3.15/3.16 的措辞。
3. **只写 `AGENTS.md` 的项目版本无关**，但强度也最低；要用就配 hook，别指望它压住引擎里的安全段。

## 项目索引

按"能不能在 3.17.2 上直接用"排序。★ 与更新时间为调研时快照。

| 项目 | ★ | 最近更新 | 机制 | 3.17.2 适配 |
| --- | --- | --- | --- | --- |
| [a0yark/zcode-prompt](https://github.com/a0yark/zcode-prompt) | 37 | 2026-09-21 | 只改 `zcode.cjs` 里 Dual-use 那段，按**解码后文案**定位，不绑混淆变量名；写入前 `node --check`、原子替换、按记录还原 | ✅ 原文 1 命中，开箱可用（实测） |
| [shenwei322/dsh-purge-ports](https://github.com/shenwei322/dsh-purge-ports) | 34 | 2026-11-03 | dsh-purge 规则移植到 ZCode / WorkBuddy：写 `~/.zcode/AGENTS.md` + `SessionStart`／`UserPromptSubmit` hook；5 套预设 + 4 skill + 4 command + 2 agent + 12 条行为探针 | ✅ 纯规则层，版本无关 |
| [YuQii-111/ZCodeDeployNew](https://github.com/YuQii-111/ZCodeDeployNew) | 73 | 2026-09-29 | 六补丁整层换 system，语义锚点 + 花括号配平定位；失败即中止、`node --check` 门禁、备份轮转 | ⚠️ 补丁 1/2 锚点失效，3/4/5/6 可打（实测） |
| [2BE-ops/zcode-prompt-toolkit](https://github.com/2BE-ops/zcode-prompt-toolkit) | 6 | 2026-09-20 | 插到**第一条 system message**；另把全包 1651 条内置 prompt 变成可编辑变量（3.14.1 验证） | ⚠️ 同款锚点需重锚，catalog 需重跑生成器 |
| [dazhiyi2/jailbreak-tool](https://github.com/dazhiyi2/jailbreak-tool) | 5 | 2026-10-23 | C# 桌面，三目标（DSH / ZCode / opencode）；`zcode.cjs` 五道字符串补丁 + `AGENTS.md`，**读 `model-io` 日志验生效** | ⚠️ 目标写的是 3.14.x，补丁需换锚点；验收思路最值得抄 |
| [chiina66/zcode-prompt-inject](https://github.com/chiina66/zcode-prompt-inject) | 18 | 2026-11-03 | 3.15.1 定制整包：设置页加「提示词注入」→ `# Global System Prompt` 稳定段；删 `SECURITY_NOTICE`；去掉 2 万字上限 | ❌ 装它等于降级覆盖 3.17.2；本机包里 `Global System Prompt`／`SECURITY_NOTICE` 均 0 命中（实测） |
| [hengkicode/ZCode-Jailbreak](https://github.com/hengkicode/ZCode-Jailbreak) | 1 | 2026-10-23 | `AGENTS.md` + 斜杠命令（`/godmode` `/deep` `/re` `/systems` `/audit`）+ 2 个 skill | ✅ 规则层可用，内容偏薄 |
| [ZiChuanLan/agent-purge](https://github.com/ZiChuanLan/agent-purge) | 1499 | 2026-11-09 | 跨宿主 persona 替换／注入（codex / claude / opencode / grok / hermes / pi / zcode），本地 web 控制台 | ⚠️ README 明确写 **zcode 未计为本轮通过**，别当成品用 |
| [zzooymc-source/ZCode-Deploy](https://github.com/zzooymc-source/ZCode-Deploy) | 30 | 2026-09-02 | v1 原版，硬编码压缩后的混淆变量名（`Djo`／`Eut`／`fre`） | ❌ ZCode 2026-09 重打包后全部失效，已被上面的 fork 取代 |
| [junpo2008/zcode-armor-breaker](https://github.com/junpo2008/zcode-armor-breaker) | 5 | 2026-08-29 | 号称给智谱 Z.ai Agentic CLI 做破甲 | ❌ 仓库内容读不到（空／已删） |

各项目 README 要点、许可与目标版本见 [docs/upstream-index.md](docs/upstream-index.md)。

## 3.17.2 锚点实测

测试对象：ZCode **3.17.2.9661**（Windows x64），引擎 `resources/glm/zcode.cjs`，15,405,949 字符。

上游项目里写的锚点，在这个版本上的真实命中数：

| 上游假设的锚点 | 3.17.2 实测 | 命中 |
| --- | --- | --- |
| `"You are ZCode, an interactive coding agent"` | 真实为 `hBa="You are ZCode, an interactive agent"` | ❌ 0 |
| `this.config.customSystemPrompt?.trim()` | 真实为 `this.config.customSystemPrompt` + `i=!!o?.trim()` | ❌ 0 |
| `name:"Agent Identity",source:"identity"` | 一致 | ✅ 1 |
| `name:"Skills",source:"skills"` | 一致 | ✅ 1 |
| `name:"Current Date",source:"current_date"` | 一致 | ✅ 1 |
| `name:"Request User Context"` | 一致 | ✅ 1 |
| `IMPORTANT: Assist with authorized security testing…`（Dual-use 全文） | `cBo="IMPORTANT: Assist with authorized security testing, …"` | ✅ 1 |
| `buildSecurityNotice` | 还在（拼接函数为 `yBa()`，CLI prefix section 为 `q8e()`） | ✅ 1 |
| `Global System Prompt` / `SECURITY_NOTICE` | 不存在 | ❌ 0 |
| `Refuse requests for destructive techniques` | 存在（Dual-use 段内） | ✅ 1 |

要跑这两行锚点修正：

```
"You are ZCode, an interactive coding agent"  →  "You are ZCode, an interactive agent"
this.config.customSystemPrompt?.trim()        →  this.config.customSystemPrompt
```

完整的常量名、上下文片段与取证命令见 [docs/anchors-3.17.2.md](docs/anchors-3.17.2.md)。重跑统计：

```powershell
# 自动找安装位置，自动读版本号
powershell -ExecutionPolicy Bypass -File scripts\probe-zcode-anchors.ps1

# 指定引擎 / 安装目录 / exe，并打印命中处的上下文
powershell -ExecutionPolicy Bypass -File scripts\probe-zcode-anchors.ps1 -Engine "<ZCode 安装目录>" -Context
```

脚本只读不写。它会直接告诉你这个版本上：Dual-use 文案是不是唯一命中、身份句措辞变了没有、`customSystemPrompt` 是哪种写法、四个 section 标签还在不在——也就是**上游哪个项目能打、哪个要改锚点**。

PowerShell 7 用户把 `powershell -ExecutionPolicy Bypass -File` 换成 `pwsh -File` 即可；脚本以 UTF-8 with BOM 保存，5.1 与 7 都能正确读中文。

## 落地路线

### 第一层：规则（抗升级，先做）

```bash
git clone https://github.com/shenwei322/dsh-purge-ports
cd dsh-purge-ports

node bin/purge.mjs install --host zcode --scope user   # 写 ~/.zcode/AGENTS.md
node bin/purge.mjs doctor                             # 体积、sha256、hook 自检
node bin/purge.mjs probe                              # 12 条行为探针，命中 ≥10 算到位
```

插件通道（自动刷新、不靠单次注入）：

```bash
node bin/purge.mjs install --host zcode --scope user
# 或走 ZCode 插件市场：插件 → 添加市场 → 指到仓库根 → 安装 purge-zcode
```

### 第二层：引擎（改 Dual-use 那一刀）

```bash
git clone https://github.com/a0yark/zcode-prompt && cd zcode-prompt
pip install -r requirements.txt

# 引擎路径：设 ZCODE_ENGINE，或让脚本自己扫默认目录/桌面快捷方式
set ZCODE_ENGINE=<ZCode 安装目录>\resources\glm\zcode.cjs

python zcode-prompt.py status     # 确认定位到官方 Dual-use 原文
python zcode-prompt.py bypass     # 换成内置破限词
python zcode-prompt.py reset      # 随时还原
```

打完**完全退出 ZCode（含托盘进程）再启动**——已开会话的 system prompt 是进程启动时组装好的，不会热更新。

### 第三层（可选）：整层替换 system

只有想让自己的词独占 system 层才需要。用 `ZCodeDeployNew`，并按上面表格改两行锚点；它的安装目录探测列表里没有自定义盘符时，设 `ZCODE_DIR=<ZCode 安装目录>`。

它的失败语义是安全的：任一补丁未命中就不落盘、退出码 1 并打印注入点诊断。

## 验收方法

唯一可信的判据是模型实际收到的请求，不是窗口标题、不是模型的自我描述：

```powershell
# system 段里这两串应当消失
Select-String -Path "$env:USERPROFILE\.zcode\cli\rollout\model-io-sess_*.jsonl" `
              -Pattern "You are ZCode","authorized security testing" |
  Select-Object -First 5
```

要点：

- 日志是明文 JSONL，`~/.zcode/cli/rollout/model-io-sess_<uuid>.jsonl`；
- 老会话不会变，**新开会话**才是新 system；
- 会话标题走另一路短请求（独立 system 常量），标题里出现拒绝句不代表补丁没打上；
- `setting.json` 里 `modelIoFullRetentionEnabled` 为 `false` 时日志有截断，长会话要留意。

## 生态备注

- 上游 `YuJunZhiXue/dsh-purge`（dsh-purge 正主，Apache-2.0）已 **404 删库**，npm 包同步消失。全量镜像：[mmparko/dsh-purge](https://github.com/mmparko/dsh-purge) ★3762、[WoYun520/dsh-purge](https://github.com/WoYun520/dsh-purge) ★566、[ZXEB/dsh-purge](https://github.com/ZXEB/dsh-purge) ★248。
- 生态里有人把 dsh-purge 打包成 388u 收费版，还有把上游规则剪一版就挂自己名字的；dsh-purge-ports 的 NOTICE 要求二开署名，别买。
- ZCode 更新会覆盖 `zcode.cjs`：引擎层补丁全失效，规则层和 hook 不受影响。所以两层一起上最省事。
- 部分项目（如 `chiina66/zcode-prompt-inject`）发的是**整包定制安装包**而不是补丁，装下去等于把官方版本降级并覆盖，自动更新还会把它冲掉。用之前先确认包内版本号和自己的版本。

## 仓库结构

```
.
├── README.md                      本文件：索引 + 实测 + 路线
├── docs/
│   ├── anchors-3.17.2.md          3.17.2 引擎包锚点取证（常量名、上下文、命中）
│   └── upstream-index.md          10 个上游项目的元数据、许可、目标版本、要点
└── scripts/
    └── probe-zcode-anchors.ps1    对任意 zcode.cjs 跑锚点命中统计
```

## 免责

仅记录公开仓库的调研结果与本机自装软件的字符串探测，用于判断哪个项目适配自己装的版本。所有引擎层改动都在本机、可还原；不涉及任何服务端。各项目请遵守其自身许可与服务条款。
