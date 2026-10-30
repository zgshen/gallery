@echo off
chcp 65001 >nul 2>&1
setlocal

:: 生成 media.json（Windows 版本，功能与 generate_json.sh 相同）
:: 用法: generate_json.bat [图片文件夹]
:: 不指定文件夹时使用当前目录，并在该目录生成 media.json
:: 也可以把文件夹直接拖到这个 bat 文件上
:: 路径中如果有空格，请用英文双引号括起来
:: 如果该文件夹下已有 media.json，则保留其中的 title、description、
:: custom_thumbnail、datetime、reverse 字段的值，以及每张图片已有的 description，
:: 只根据当前文件夹里的图片更新 images 列表（新图片加入，已删除的图片移除）
:: 需要 Windows 自带的 PowerShell（Windows 7 SP1 及以上）
:: 设置环境变量 NOPAUSE=1 可以在结束时不暂停

if not "%~2"=="" (
    echo 用法: %~nx0 [图片文件夹]
    echo 路径中如果有空格，请用英文双引号括起来
    set "RC=1"
    goto :done
)

set "TARGET_DIR=%~1"
set "SELF=%~f0"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$f=[IO.File]::ReadAllText($env:SELF,[Text.Encoding]::UTF8); $s=$f.Substring($f.LastIndexOf('#PS_START')); $r=@(& ([scriptblock]::Create($s))); exit [int]$r[-1]"
set "RC=%errorlevel%"

:done
if not defined NOPAUSE pause
exit /b %RC%

#PS_START
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

# JSON 字符串转义函数（处理反斜杠和双引号）
function JsonEscape([string]$s) {
    return $s.Replace('\', '\\').Replace('"', '\"')
}

# 从一段 JSON 文本中读取某个字段的原始 JSON 值（字符串带引号）；找不到返回 $null
function ReadField([string]$text, [string]$name) {
    $m = [regex]::Match($text, '"' + [regex]::Escape($name) + '"\s*:\s*("(?:[^"\\]|\\.)*"|[^,}\s]+)')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

function Main {
    $target = $env:TARGET_DIR
    if ([string]::IsNullOrEmpty($target)) { $target = '.' }

    if (-not (Test-Path -LiteralPath $target -PathType Container)) {
        Write-Host "错误: 文件夹不存在: $target"
        return 1
    }

    $dir = (Resolve-Path -LiteralPath $target).ProviderPath
    $outfile = Join-Path $dir 'media.json'
    $utf8 = New-Object System.Text.UTF8Encoding -ArgumentList $false

    # 默认值（原来没有 media.json，或其中缺少某个字段时使用）
    $vTitle = '""'
    $vDescription = '""'
    $vDatetime = '""'
    $vReverse = 'false'
    $vThumb = $null
    $hasOld = $false
    $oldDescs = @{}

    # 如果已有 media.json，读取这几个字段的旧值，以及每张图片的旧描述
    if (Test-Path -LiteralPath $outfile -PathType Leaf) {
        $hasOld = $true
        $old = [System.IO.File]::ReadAllText($outfile, [System.Text.Encoding]::UTF8)

        # "images" 之前的部分是顶层字段，避免误读图片里的字段
        $idx = $old.IndexOf('"images"')
        if ($idx -ge 0) { $header = $old.Substring(0, $idx) } else { $header = $old }

        $v = ReadField $header 'title';            if ($null -ne $v) { $vTitle = $v }
        $v = ReadField $header 'description';      if ($null -ne $v) { $vDescription = $v }
        $v = ReadField $header 'custom_thumbnail'; if ($null -ne $v) { $vThumb = $v }
        $v = ReadField $header 'datetime';         if ($null -ne $v) { $vDatetime = $v }
        $v = ReadField $header 'reverse';          if ($null -ne $v) { $vReverse = $v }

        # 逐个读取旧 images 里的 "文件名": { ... } 条目，记下各自的 description
        if ($idx -ge 0) {
            $rest = $old.Substring($idx + '"images"'.Length)
            $imgRe = '"((?>[^"\\]+|\\.)*)"\s*:\s*(\{(?>[^{}"]+|"(?>[^"\\]+|\\.)*")*\})'
            foreach ($m in [regex]::Matches($rest, $imgRe)) {
                $d = ReadField $m.Groups[2].Value 'description'
                if ($null -eq $d) { $d = '""' }
                $oldDescs[$m.Groups[1].Value] = $d
            }
        }
    }

    # 收集图片文件（不区分大小写）
    $exts = @('.jpg', '.jpeg', '.png', '.gif', '.bmp')
    $files = @(Get-ChildItem -LiteralPath $dir -File | Where-Object { $exts -contains $_.Extension.ToLower() } | Sort-Object Name)
    $count = $files.Count

    # 缩略图：旧文件里有 custom_thumbnail 就沿用，否则用第一个图片文件，没有图片则为空
    if ($null -eq $vThumb) {
        if ($count -gt 0) {
            $first = $files[0].Name
            $vThumb = '"' + (JsonEscape $first) + '"'
        } else {
            $vThumb = '""'
        }
    }

    $nl = "`r`n"
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('{' + $nl)
    [void]$sb.Append('  "title": ' + $vTitle + ',' + $nl)
    [void]$sb.Append('  "description": ' + $vDescription + ',' + $nl)
    [void]$sb.Append('  "custom_thumbnail": ' + $vThumb + ',' + $nl)
    [void]$sb.Append('  "datetime": ' + $vDatetime + ',' + $nl)
    [void]$sb.Append('  "reverse": ' + $vReverse + ',' + $nl)

    $kept = 0
    if ($count -eq 0) {
        # 没有文件的情况
        [void]$sb.Append('  "images": {}' + $nl)
    } else {
        [void]$sb.Append('  "images": {' + $nl)
        for ($i = 0; $i -lt $count; $i++) {
            $name = JsonEscape $files[$i].Name

            # 旧文件里有这张图片的描述就沿用，否则为空
            $desc = '""'
            if ($oldDescs.ContainsKey($name)) {
                $desc = $oldDescs[$name]
                $kept++
            }

            # 最后一个文件不加逗号
            $comma = ''
            if ($i -lt ($count - 1)) { $comma = ',' }

            [void]$sb.Append('    "' + $name + '": {' + $nl)
            [void]$sb.Append('        "description": ' + $desc + $nl)
            [void]$sb.Append('    }' + $comma + $nl)
        }
        [void]$sb.Append('  }' + $nl)
    }
    [void]$sb.Append('}' + $nl)

    # 先写到临时文件，成功后再替换，避免中途出错丢失原有 media.json
    $tmp = $outfile + '.tmp'
    [System.IO.File]::WriteAllText($tmp, $sb.ToString(), $utf8)
    Move-Item -LiteralPath $tmp -Destination $outfile -Force

    if ($count -eq 0) {
        if ($hasOld) { Write-Host '已保留原有 media.json 的字段' }
        Write-Host '没有找到图片文件'
        return 0
    }

    if ($hasOld) {
        Write-Host '已保留原有 media.json 的 title/description/custom_thumbnail/datetime/reverse'
        Write-Host "沿用了 $kept 张图片已有的描述"
    }
    Write-Host "生成完成: $outfile"
    Write-Host "共处理 $count 个文件"
    return 0
}

try {
    $rc = Main
} catch {
    Write-Host ('错误: ' + $_.Exception.Message)
    $rc = 1
}
return $rc
