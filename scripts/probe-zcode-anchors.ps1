<#
.SYNOPSIS
    对 ZCode 引擎包（resources/glm/zcode.cjs）做锚点命中统计。

.DESCRIPTION
    ZCode 在运行时从 zcode.cjs 里的字符串字面量拼出整个 system prompt。
    上游的提示词改造项目都靠"定位某个字面量再原地替换"来工作，
    所以版本一升级、措辞一改，锚点就会 0 命中。

    本脚本不改任何文件，只报告：
      · 引擎身份（版本、大小、SHA-256）
      · 每条锚点的命中次数
      · 对 0 命中的锚点给出该版本里的真实形态（如果认得出来）

.PARAMETER Engine
    zcode.cjs 的完整路径，或 ZCode 安装根目录、ZCode.exe、ZCode.app。
    省略时按默认安装位置查找。

.PARAMETER Context
    对命中的锚点额外打印 200 字符上下文，便于确认改的是哪一段。

.PARAMETER Json
    以 JSON 输出（便于喂给别的脚本）。

.EXAMPLE
    pwsh -File probe-zcode-anchors.ps1
    pwsh -File probe-zcode-anchors.ps1 -Engine "D:\apps\ZCode" -Context
#>
[CmdletBinding()]
param(
    [string]$Engine,
    [switch]$Context,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Resolve-EnginePath {
    param([string]$Hint)

    $candidates = New-Object System.Collections.ArrayList

    if ($Hint) {
        if (Test-Path -LiteralPath $Hint -PathType Leaf) {
            [void]$candidates.Add((Resolve-Path -LiteralPath $Hint).Path)
            # 给的是 ZCode.exe：同级 resources\glm\zcode.cjs
            $dir = Split-Path -Parent (Resolve-Path -LiteralPath $Hint).Path
            [void]$candidates.Add((Join-Path $dir 'resources\glm\zcode.cjs'))
            [void]$candidates.Add((Join-Path $dir 'resources/glm/zcode.cjs'))
        }
        elseif (Test-Path -LiteralPath $Hint -PathType Container) {
            $root = (Resolve-Path -LiteralPath $Hint).Path
            foreach ($rel in @('resources\glm\zcode.cjs', 'resources/glm/zcode.cjs',
                               'Contents\Resources\glm\zcode.cjs', 'Contents/Resources/glm/zcode.cjs',
                               'glm\zcode.cjs', 'glm/zcode.cjs')) {
                [void]$candidates.Add((Join-Path $root $rel))
            }
        }
    }

    foreach ($envName in @('ZCODE_ENGINE', 'ZCODE_DIR', 'ZCODE_HOME')) {
        $val = [Environment]::GetEnvironmentVariable($envName)
        if ($val) {
            foreach ($rel in @('resources\glm\zcode.cjs', 'resources/glm/zcode.cjs',
                               'Contents/Resources/glm/zcode.cjs')) {
                [void]$candidates.Add((Join-Path $val $rel))
            }
            [void]$candidates.Add($val)
        }
    }

    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        foreach ($base in @($env:LOCALAPPDATA, $env:ProgramFiles, ${env:ProgramFiles(x86)})) {
            if ($base) {
                [void]$candidates.Add((Join-Path $base 'Programs\ZCode\resources\glm\zcode.cjs'))
                [void]$candidates.Add((Join-Path $base 'ZCode\resources\glm\zcode.cjs'))
            }
        }
        foreach ($drive in @('C:', 'D:', 'E:', 'F:')) {
            foreach ($sub in @('zcode', 'app\zcode', 'apps\zcode', 'Program Files\ZCode', 'ZCode')) {
                [void]$candidates.Add(("{0}\{1}\resources\glm\zcode.cjs" -f $drive, $sub))
            }
        }
    }
    else {
        foreach ($p in @('/Applications/ZCode.app/Contents/Resources/glm/zcode.cjs',
                         "$HOME/Applications/ZCode.app/Contents/Resources/glm/zcode.cjs",
                         "$HOME/.local/share/ZCode/resources/glm/zcode.cjs",
                         '/opt/ZCode/resources/glm/zcode.cjs',
                         '/usr/lib/zcode/resources/glm/zcode.cjs')) {
            [void]$candidates.Add($p)
        }
    }

    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c -PathType Leaf)) {
            $item = Get-Item -LiteralPath $c
            if ($item.Length -gt 1MB) { return $item.FullName }
        }
    }
    return $null
}

<#
    锚点表。Kind 用来分类：
      identity  身份句（决定了产品人格是否还在）
      security  安全边界（最值得改的一段）
      section   section 注册标签（跨版本最稳的结构锚点）
      custom    产品自带的 customSystemPrompt 入口
      absent    只做存在性探测，不该出现
#>
$anchorTable = @(
    @{ Id = 'identity-strict'; Kind = 'identity'; Pattern = '"You are ZCode, an interactive coding agent"';
       Note = '3.15/3.16 的措辞，3.17 起为 "an interactive agent"' }
    @{ Id = 'identity-loose';  Kind = 'identity'; Pattern = 'You are ZCode, an interactive agent';
       Note = '去掉引号的宽松匹配，用于判断身份句还在不在' }
    @{ Id = 'custom-optional-chain'; Kind = 'custom'; Pattern = 'this.config.customSystemPrompt?.trim()';
       Note = '3.15/3.16 的写法' }
    @{ Id = 'custom-field';    Kind = 'custom'; Pattern = 'this.config.customSystemPrompt';
       Note = '3.17 起的写法（另配 i=!!o?.trim()）' }
    @{ Id = 'section-identity'; Kind = 'section'; Pattern = 'name:"Agent Identity",source:"identity"';
       Note = 'system 层，最值得动' }
    @{ Id = 'section-skills';  Kind = 'section'; Pattern = 'name:"Skills",source:"skills"';
       Note = 'meta_user 层' }
    @{ Id = 'section-date';    Kind = 'section'; Pattern = 'name:"Current Date",source:"current_date"';
       Note = 'meta_user 层' }
    @{ Id = 'section-userctx'; Kind = 'section'; Pattern = 'name:"Request User Context"';
       Note = 'meta_user 层' }
    @{ Id = 'security-text';   Kind = 'security'; Pattern = 'IMPORTANT: Assist with authorized security testing';
       Note = 'Dual-use 段落开头，按文案定位最稳' }
    @{ Id = 'security-fn';     Kind = 'security'; Pattern = 'buildSecurityNotice';
       Note = '函数名，可能被 minify 掉' }
    @{ Id = 'security-body';   Kind = 'security'; Pattern = 'Refuse requests for destructive techniques';
       Note = 'Dual-use 段正文，改段落后应消失' }
    @{ Id = 'absent-gsp';      Kind = 'absent';   Pattern = 'Global System Prompt';
       Note = '3.15.1 定制包的注入段名，官方包应为 0' }
    @{ Id = 'absent-notice';   Kind = 'absent';   Pattern = 'SECURITY_NOTICE';
       Note = '同上' }
)

$enginePath = Resolve-EnginePath -Hint $Engine
if (-not $enginePath) {
    Write-Error "没找到 zcode.cjs。用 -Engine 指定 ZCode 安装目录、ZCode.exe 或 zcode.cjs 本身。"
    exit 2
}

$file = Get-Item -LiteralPath $enginePath
$raw = [System.IO.File]::ReadAllText($enginePath)
$sha = (Get-FileHash -LiteralPath $enginePath -Algorithm SHA256).Hash

# 版本：同目录或上两级的 ZCode.exe
$version = $null
$dir = Split-Path -Parent $file.FullName
foreach ($probe in @(
        (Join-Path (Split-Path -Parent (Split-Path -Parent $dir)) 'ZCode.exe'),
        (Join-Path (Split-Path -Parent $dir) 'ZCode.exe'),
        'ZCode.exe')) {
    if ($probe -and (Test-Path -LiteralPath $probe -PathType Leaf)) {
        try { $version = (Get-Item -LiteralPath $probe).VersionInfo.FileVersion } catch { }
        if ($version) { break }
    }
}

$results = New-Object System.Collections.ArrayList
foreach ($a in $anchorTable) {
    $count = ([regex]::Matches($raw, [regex]::Escape($a.Pattern))).Count
    $entry = [ordered]@{
        id      = $a.Id
        kind    = $a.Kind
        pattern = $a.Pattern
        count   = $count
        hit     = ($count -gt 0)
        note    = $a.Note
    }
    if ($Context -and $count -gt 0) {
        $m = [regex]::Match($raw, [regex]::Escape($a.Pattern))
        $start = [Math]::Max(0, $m.Index - 100)
        $len = [Math]::Min(300, $raw.Length - $start)
        $entry.context = ($raw.Substring($start, $len) -replace "`r?`n", ' ')
    }
    [void]$results.Add([pscustomobject]$entry)
}

if ($Json) {
    [ordered]@{
        engine  = $enginePath
        size    = $file.Length
        sha256  = $sha
        version = $version
        anchors = $results
    } | ConvertTo-Json -Depth 5
    exit 0
}

Write-Host ""
Write-Host "ZCode 引擎锚点探测" -ForegroundColor Cyan
Write-Host ("  引擎   {0}" -f $enginePath)
Write-Host ("  版本   {0}" -f $(if ($version) { $version } else { '(未识别)' }))
Write-Host ("  大小   {0:N0} 字节" -f $file.Length)
Write-Host ("  SHA256 {0}" -f $sha)
Write-Host ""

$groups = @(
    @{ Title = '身份句'; Tag = 'identity'; Color = 'Yellow' }
    @{ Title = '安全边界（Dual-use）'; Tag = 'security'; Color = 'Yellow' }
    @{ Title = 'customSystemPrompt 入口'; Tag = 'custom'; Color = 'Gray' }
    @{ Title = 'section 注册标签'; Tag = 'section'; Color = 'Green' }
    @{ Title = '不该存在（定制包特征）'; Tag = 'absent'; Color = 'DarkGray' }
)

foreach ($g in $groups) {
    Write-Host ("── {0}" -f $g.Title) -ForegroundColor $g.Color
    foreach ($r in $results) {
        if ($r.kind -ne $g.Tag) { continue }
        $mark = if ($r.count -gt 0) { '✓' } else { '·' }
        $color = if ($r.count -gt 0) { 'White' } else { 'DarkGray' }
        Write-Host ("  {0} {1,-22} {2,2} 命中   {3}" -f $mark, $r.id, $r.count, $r.pattern) -ForegroundColor $color
        if ($r.context) {
            Write-Host ("      …{0}…" -f $r.context) -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}

$strict = ($results | Where-Object { $_.id -eq 'identity-strict' }).count
$loose = ($results | Where-Object { $_.id -eq 'identity-loose' }).count
$secText = ($results | Where-Object { $_.id -eq 'security-text' }).count
$secBody = ($results | Where-Object { $_.id -eq 'security-body' }).count
$customField = ($results | Where-Object { $_.id -eq 'custom-field' }).count
$secSections = @('section-identity', 'section-skills', 'section-date', 'section-userctx') |
    ForEach-Object { $id = $_; ($results | Where-Object { $_.id -eq $id }).count } |
    Where-Object { $_ -gt 0 }

Write-Host "── 判断" -ForegroundColor Cyan

if ($secText -eq 1) {
    Write-Host "  ✓ Dual-use 原文唯一命中 —— 按文案定位的补丁（如 a0yark/zcode-prompt）可以打。" -ForegroundColor Green
}
elseif ($secText -eq 0) {
    Write-Host "  ✗ Dual-use 原文 0 命中 —— 措辞已变，按文案定位的补丁会拒绝执行。" -ForegroundColor Red
    Write-Host "    先确认 buildSecurityNotice / Refuse requests 还在不在，再用仍存在的片段重新定位。" -ForegroundColor DarkGray
}
else {
    Write-Host ("  ! Dual-use 原文命中 {0} 次（应唯一）—— 补丁类工具会因歧义中止。" -f $secText) -ForegroundColor Yellow
}

if ($secBody -eq 0 -and $secText -eq 0) {
    Write-Host "  提示：安全边界可能已被改写过，或这个版本不再内联这段文案。" -ForegroundColor DarkGray
}

if ($strict -eq 0 -and $loose -gt 0) {
    Write-Host "  ! 身份句措辞已改（strict 0 / loose $loose）—— 整层替换型项目需把锚点从" -ForegroundColor Yellow
    Write-Host '    "You are ZCode, an interactive coding agent" 改为 "You are ZCode, an interactive agent"。' -ForegroundColor DarkGray
}

if ($customField -gt 0 -and ($results | Where-Object { $_.id -eq 'custom-optional-chain' }).count -eq 0) {
    Write-Host "  ! customSystemPrompt 写法已改（可选链 trim 判断不存在）—— 补丁 2 需改用 this.config.customSystemPrompt。" -ForegroundColor Yellow
}

if ($secSections.Count -eq 4) {
    Write-Host "  ✓ 四个 section 注册标签全部命中 —— 结构性锚点可用，改它们比改文案稳。" -ForegroundColor Green
}

Write-Host ""
Write-Host "下一步：把本机这一版的实际形态记进 docs/anchors-<版本>.md，再决定改哪一类锚点。" -ForegroundColor DarkGray
exit 0
