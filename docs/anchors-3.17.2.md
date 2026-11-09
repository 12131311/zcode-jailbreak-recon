# ZCode 3.17.2 引擎包锚点取证

本文件记录一次可复现的字符串级探测：ZCode 桌面端把整个 system prompt 在运行时从 `resources/glm/zcode.cjs` 里的字符串字面量拼出来，所以定位"哪句话是锚点、还存不存在"就是在定位可改点。

## 测试对象

| 项 | 值 |
| --- | --- |
| 应用 | ZCode（智谱 Z.ai） |
| 版本 | 3.17.2.9661（Windows x64） |
| 引擎文件 | `<install>\resources\glm\zcode.cjs` |
| 大小 | 15,408,074 字节 |
| SHA-256 | `D9AFD58D694F98A5279BF548CDC7646413C125762E86730605A6071F9E0346D6` |
| 文件时间 | 2026-11-02 14:51:14 |
| 形态 | minify 后的单文件 CJS，Electron 以 `ELECTRON_RUN_AS_NODE` 入口加载 |

其他版本请用同法自测，不要照搬本表。

## 复现方式

```powershell
$f = '<install>\resources\glm\zcode.cjs'
$raw = [System.IO.File]::ReadAllText($f)

$anchors = @(
  '"You are ZCode, an interactive coding agent"',
  'this.config.customSystemPrompt?.trim()',
  'name:"Agent Identity",source:"identity"',
  'name:"Current Date",source:"current_date"',
  'name:"Skills",source:"skills"',
  'name:"Request User Context"',
  'IMPORTANT: Assist with authorized security testing',
  'buildSecurityNotice',
  'Global System Prompt',
  'SECURITY_NOTICE',
  'Refuse requests for destructive techniques'
)
foreach ($a in $anchors) {
  '{0,-52} : {1}' -f $a, ([regex]::Matches($raw, [regex]::Escape($a))).Count
}
```

或直接跑本仓库的 [probe-zcode-anchors.ps1](../scripts/probe-zcode-anchors.ps1)。

## 命中结果

| 锚点 | 命中 | 结论 |
| --- | --- | --- |
| `"You are ZCode, an interactive coding agent"` | 0 | 措辞已改，见下文真实形态 |
| `this.config.customSystemPrompt?.trim()` | 0 | 写法已改 |
| `name:"Agent Identity",source:"identity"` | 1 | 可用 |
| `name:"Current Date",source:"current_date"` | 1 | 可用 |
| `name:"Skills",source:"skills"` | 1 | 可用 |
| `name:"Request User Context"` | 1 | 可用 |
| `IMPORTANT: Assist with authorized security testing` | 1 | **Dual-use 原文整段仍在，且只出现一次** |
| `buildSecurityNotice` | 1 | 函数名仍在（拼接落在 `yBa()`） |
| `Global System Prompt` | 0 | 3.15.1 定制包的注入段名，官方包里没有 |
| `SECURITY_NOTICE` | 0 | 同上 |
| `Refuse requests for destructive techniques` | 1 | Dual-use 段正文内 |

## 关键上下文（原文摘录）

### 1. 身份句：CLI prefix section

```js
hBa="You are ZCode, an interactive agent";r(q8e,"buildCliPrefixSection")
function lBo(){return cBo}function kDn(e=!0){return["# Harness",
  " - Text you output outside of tool ...
```

要点：

- 身份句是模块级常量 `hBa`，由 `q8e()`（`buildCliPrefixSection`）产出；
- 上游项目找的 `an interactive coding agent` 在这里是 `an interactive agent`——**掉了 `coding` 一个词，整条锚点就 0 命中**；
- 同文件另有 `"You are ZCode Explore, a file search and codebase research specialist ..."`（子代理）和 `"You are ZCode connectivity probe."`（连通性探测），都不该动。

### 2. 安全边界：Dual-use 段落

```js
_Ba='You are an interactive agent that helps users according to your "Output Style", ...'
cBo="IMPORTANT: Assist with authorized security testing, defensive security, CTF challenges,
     and educational contexts. Refuse requests for destructive techniques, DoS attacks,
     mass targeting, supply chain compromise, or detection evasion for malicious purposes.
     Dual-use security tools (C2 frameworks, credential testing, exploit development)
     require clear authorization context: pentesting engagements, CTF competitions,
     security research, or defensive use cases."
```

拼接处：

```js
function yBa(e,t){return[["",e?_Ba:gBa,"",cBo].join(` `),"",kDn(t)].join(` `)}
function xDn(e,t=!0){let n=yBa(e,t);return{name:"Agent Identity",source:"identity",
  injectionTarget:"system",cacheHint:"stable",chars:n.length,tokens:ef(n),content:...
```

要点：

- `cBo` 是模块级**单引号/双引号字面量**（早期版本叫 `$Oi`／`weo`／`keo`，会随构建改名），所以按**解码后的文案**定位比按变量名稳；
- 这一段是 `Agent Identity` section 的一部分，落 `injectionTarget:"system"`，`cacheHint:"stable"`——改它等于改 system 层地基；
- 改完必须重启：`cacheHint:"stable"` 的段落由进程在启动时组装。

### 3. `customSystemPrompt` 入口（产品自带的合法注入点）

```js
build(){let t=[],n=this.config.outputStyle?.prompt.trim()?this.config.outputStyle:void 0,
  o=this.config.customSystemPrompt,i=!!o?.trim(),a=this.config.workflowActor;
  if(a!==void 0&&i)throw new Error("ContextBuilder: workflowActor and customSystemPrompt are mutually exclusive");
  ...
  c||t.push(q8e()),
  i?t.push(R3a({name:"Custom System Prompt",source:"custom_system_prompt",
                 injectionTarget:"system",cacheHint:"stable",...
```

要点：

- 3.17.2 里写作 `this.config.customSystemPrompt`，判断是 `i=!!o?.trim()`——上游项目里的 `this.config.customSystemPrompt?.trim()` 这一整串不存在，所以按它打会 0 命中；
- `i` 为真时压入 `Custom System Prompt` section，且和 `workflowActor` 互斥；
- 另一处（`13334911`）是 `customSystemPrompt:this.config.systemPrompt`，说明 `systemPrompt` 配置会灌进这个字段——这就是"整层替换"型项目走的通道；
- 它是产品自带能力，不是补丁，所以最不容易被更新打掉。

### 4. 其余可打的 section 锚点

```js
function W8e(e){ if(e.outcome.skills.length===0) return null; ... {name:"Skills",source:"skills",injectionTarget:"meta_user",cacheHint:"dynamic",...} }
function fce(e){ if(!e) return null; let t=`Today's date is ${e}.`; ... {name:"Current Date",source:"current_date",injectionTarget:"meta_user",cacheHint:"dynamic",...} }
function Nxt(e){ let t=h3a(e); return t?{name:"Request User Context",source:"request_user_context",injectionTarget:"meta_user",cacheHint:"dynamic",...}:... }
```

要点：

- 这三段都是 `injectionTarget:"meta_user"`——不是 system，是 meta user 消息，所以删它们收益有限，但能省 token、少一层"环境事实"竞争；
- 它们的函数体以 `if(...) return null` 开头，插 `return null;` 是最小改动；
- `Agent Identity` 段（`xDn`）是 system 层，改它收益最大。

## 对上游项目的逐条判断

| 项目 | 补丁 1（身份句） | 补丁 2（customSystemPrompt） | 补丁 3–6（section 构造） | Dual-use 段 |
| --- | --- | --- | --- | --- |
| `YuQii-111/ZCodeDeployNew` | ❌ 锚点失效 | ❌ 锚点失效 | ✅ 四条都在 | 未单独处理 |
| `2BE-ops/zcode-prompt-toolkit` | ❌ 同款锚点 | — | — | 未单独处理 |
| `a0yark/zcode-prompt` | 不动身份句 | 不用 | 不动 section | ✅ 文案锚点仍 1 命中 |
| `dazhiyi2/jailbreak-tool` | 依赖 3.14.x 锚点 | — | — | 五道补丁之一，需重锚 |
| `chiina66/zcode-prompt-inject` | 靠定制整包 | 自带设置页 | — | 直接删 `SECURITY_NOTICE`（3.17.2 已无此串） |

`YuQii-111/ZCodeDeployNew` 的失败语义是安全的：任一补丁未命中即中止、退出码 1、不落盘。所以它在 3.17.2 上不会写坏文件，只会拒绝执行——把上表两行锚点改掉即可。

## 两个观察

1. **锚点会跟着措辞走，不跟着结构走。** `hBa` 的变量名 3.15 → 3.17 没变，但它指向的句子少了一个 `coding`；`customSystemPrompt` 的用法从"可选链 trim 判断"变成"取变量再判真"。靠压缩变量名硬编码的 v1 项目（`zzooymc-source/ZCode-Deploy`）在 2026-09 的重打包里直接全灭，靠语义字面量的项目活下来了。
2. **稳定的其实只有语义块名。** `name:"X",source:"y"` 这四个 section 标签跨三个版本都在，因为它们是 section 注册表的一部分，不是文案。真要写跨版本补丁，优先挂这类结构性锚点，再用文案做二次校验。
