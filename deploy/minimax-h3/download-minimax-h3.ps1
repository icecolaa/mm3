<#
.SYNOPSIS
    MiniMax H3 视频模型下载脚本（只下载四个模型文件）。

.DESCRIPTION
    为 ComfyUI + MiniMax H3 FL2VA 低显存部署准备模型文件。
    本脚本只做下载：不 clone 仓库、不安装依赖、不更新驱动、不启动 ComfyUI。
    使用 Windows 自带 curl.exe，支持断点续传。

    兼容 Windows PowerShell 5.1。

.PARAMETER TargetRoot
    视频根目录，默认 D:\LocalAI\video。
    脚本据此推导 ComfyUI 模型目录：
    <TargetRoot>\ComfyUI_windows_portable\ComfyUI\models\<子目录>\

.PARAMETER ModelsRoot
    直接指定 ComfyUI 的 models 目录，覆盖由 TargetRoot 推导的默认值。
    Portable 解压在别处时使用。

.PARAMETER DryRun
    只打印下载计划。零网络请求、不创建目录、不写入文件。退出码 0。

.PARAMETER HfMirror
    改用 https://hf-mirror.com 前缀下载（直连 huggingface.co 被拦截时使用）。

.PARAMETER VerifyHash
    下载完成后校验 SHA-256（需要读取全部文件，较慢）。

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\download-minimax-h3.ps1 -DryRun

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\download-minimax-h3.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\download-minimax-h3.ps1 -TargetRoot 'E:\AI\video' -HfMirror -VerifyHash

.NOTES
    清单与校验值见同目录 manifest.json，访问日期 2026-10-29。
#>

[CmdletBinding()]
param(
    [string]$TargetRoot = 'D:\LocalAI\video',
    [string]$ModelsRoot = '',
    [switch]$DryRun,
    [switch]$HfMirror,
    [switch]$VerifyHash
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# 文件清单（与 manifest.json 保持一致）
# ---------------------------------------------------------------------------
$ModelList = @(
    [pscustomobject]@{
        Index    = 1
        Role     = 'H3 FL2VA 扩散模型（W4A8）'
        Filename = 'minimax_h3_fl2va_pruned_w4a8_mixed.safetensors'
        Repo     = 'Kijai/MiniMax-H3-experimental'
        SubDir   = 'diffusion_models'
        Size     = [int64]12540858008
        Sha256   = '01aa7b92c007c599890461c325f9b7e3c96fb06c36f242f95b62f7f20e538dec'
    },
    [pscustomobject]@{
        Index    = 2
        Role     = 'Qwen3-VL 4B 文本编码器（int8 convrot）'
        Filename = 'qwen3vl_4b_int8_convrot.safetensors'
        Repo     = 'Stick9190/qwen3vl_4b_int8_convrot'
        SubDir   = 'text_encoders'
        Size     = [int64]5374169456
        Sha256   = 'ebbb3efdf4a6e1b766e32f6dc4fa92af9530edede0968c070b3e604aeca413aa'
    },
    [pscustomobject]@{
        Index    = 3
        Role     = 'H3 ClipProj 4B 投影矩阵（v3-mlp）'
        Filename = 'mmh3-4b-ClipProj-v3-mlp.safetensors'
        Repo     = 'NicoLab28/ClipProj-MiniMax-H3'
        SubDir   = 'clip_projections'
        Size     = [int64]503434368
        Sha256   = 'feef06ef3b9aede3b1f3331b71eebbc873e21a867d73bcf40ea2c0b007270693'
    },
    [pscustomobject]@{
        Index    = 4
        Role     = 'H3 视频 VAE（int8 convrot）'
        Filename = 'minimax_h3_video_vae_int8_convrot.safetensors'
        Repo     = 'Kijai/MiniMax-H3-experimental'
        SubDir   = 'vae'
        Size     = [int64]3171670912
        Sha256   = '9bb2d96f218c76babd85e0611b85ca8fb330a90546c01a0005e8a58a59593410'
    }
)

# ---------------------------------------------------------------------------
# 基础信息
# ---------------------------------------------------------------------------
if ($HfMirror) {
    $BaseUrl = 'https://hf-mirror.com'
} else {
    $BaseUrl = 'https://huggingface.co'
}

if ([string]::IsNullOrWhiteSpace($ModelsRoot)) {
    $ResolvedModelsRoot = Join-Path -Path $TargetRoot -ChildPath 'ComfyUI_windows_portable\ComfyUI\models'
} else {
    $ResolvedModelsRoot = $ModelsRoot
}

function Format-SizeGiB {
    param([int64]$Bytes)
    $gib = [double]$Bytes / 1073741824.0
    return ('{0:N2} GiB' -f $gib)
}

$TotalBytes = [int64]0
foreach ($m in $ModelList) { $TotalBytes = $TotalBytes + $m.Size }

# ---------------------------------------------------------------------------
# 标题
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '=== MiniMax H3 模型下载 ===' -ForegroundColor Cyan
Write-Host ("目标根目录 : {0}" -f $TargetRoot)
Write-Host ("模型目录   : {0}" -f $ResolvedModelsRoot)
Write-Host ("下载基地址 : {0}" -f $BaseUrl)
Write-Host ("文件数量   : {0}" -f $ModelList.Count)
Write-Host ("合计大小   : {0:N0} 字节 ({1})" -f $TotalBytes, (Format-SizeGiB -Bytes $TotalBytes))
Write-Host ''

# ---------------------------------------------------------------------------
# DryRun：只打印计划，零网络请求
# ---------------------------------------------------------------------------
if ($DryRun) {
    Write-Host '--- [DryRun] 只打印计划，不发起任何网络请求、不创建目录、不写入文件 ---' -ForegroundColor Yellow
    Write-Host ''

    foreach ($m in $ModelList) {
        $targetDir  = Join-Path -Path $ResolvedModelsRoot -ChildPath $m.SubDir
        $targetFile = Join-Path -Path $targetDir -ChildPath $m.Filename
        $url        = $BaseUrl + '/' + $m.Repo + '/resolve/main/' + $m.Filename

        $state = '不存在，将全新下载'
        if (Test-Path -LiteralPath $targetFile -PathType Leaf) {
            $existing = (Get-Item -LiteralPath $targetFile).Length
            if ($existing -eq $m.Size) {
                $state = '已存在且大小一致，将跳过'
            } elseif ($existing -lt $m.Size) {
                $state = ('已存在但偏小（{0:N0} 字节），将断点续传' -f $existing)
            } else {
                $state = ('已存在且偏大（{0:N0} 字节），将报错并停止处理该文件' -f $existing)
            }
        }

        Write-Host ("[{0}/{1}] {2}" -f $m.Index, $ModelList.Count, $m.Role) -ForegroundColor Green
        Write-Host ("     文件 : {0}" -f $m.Filename)
        Write-Host ("     来源 : {0}" -f $m.Repo)
        Write-Host ("     URL  : {0}" -f $url)
        Write-Host ("     目标 : {0}" -f $targetFile)
        Write-Host ("     大小 : {0:N0} 字节 ({1})" -f $m.Size, (Format-SizeGiB -Bytes $m.Size))
        Write-Host ("     SHA256: {0}" -f $m.Sha256)
        Write-Host ("     状态 : {0}" -f $state)
        Write-Host ''
    }

    Write-Host '--- [DryRun] 结束：未发起网络请求，未创建目录，未写入文件，退出码 0 ---' -ForegroundColor Yellow
    Write-Host ''
    exit 0
}

# ---------------------------------------------------------------------------
# 检查 curl.exe
# ---------------------------------------------------------------------------
$curlCmd = Get-Command -Name 'curl.exe' -ErrorAction SilentlyContinue
if ($null -eq $curlCmd) {
    Write-Host '错误：找不到 curl.exe。Windows 10 1803 及以上自带；请确认系统版本或在 PATH 中提供 curl.exe。' -ForegroundColor Red
    exit 1
}
$curlPath = $curlCmd.Source
Write-Host ("使用 curl : {0}" -f $curlPath)
Write-Host ''

# ---------------------------------------------------------------------------
# 下载
# ---------------------------------------------------------------------------
$exitCode   = 0
$downloaded = 0
$skipped    = 0
$failed     = 0
$hashFailed = 0

foreach ($m in $ModelList) {
    $targetDir  = Join-Path -Path $ResolvedModelsRoot -ChildPath $m.SubDir
    $targetFile = Join-Path -Path $targetDir -ChildPath $m.Filename
    $url        = $BaseUrl + '/' + $m.Repo + '/resolve/main/' + $m.Filename

    Write-Host ("[{0}/{1}] {2}" -f $m.Index, $ModelList.Count, $m.Role) -ForegroundColor Green
    Write-Host ("     {0}" -f $m.Filename)

    if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        Write-Host ("     已创建目录：{0}" -f $targetDir) -ForegroundColor DarkGray
    }

    $needDownload = $true

    if (Test-Path -LiteralPath $targetFile -PathType Leaf) {
        $existing = (Get-Item -LiteralPath $targetFile).Length

        if ($existing -eq $m.Size) {
            Write-Host ("     已存在且大小一致（{0:N0} 字节），跳过。" -f $existing) -ForegroundColor Yellow
            $needDownload = $false
            $skipped = $skipped + 1
        } elseif ($existing -gt $m.Size) {
            Write-Host ("     错误：文件已存在且比清单大（{0:N0} > {1:N0} 字节）。" -f $existing, $m.Size) -ForegroundColor Red
            Write-Host '     可能是不同来源的同名文件，或之前用了另一个源。请人工确认后删除该文件再重跑。' -ForegroundColor Red
            Write-Host '     本脚本不会删除你的文件。' -ForegroundColor Red
            $failed = $failed + 1
            $exitCode = 1
            $needDownload = $false
        } else {
            Write-Host ("     已存在但偏小（{0:N0} / {1:N0} 字节），断点续传。" -f $existing, $m.Size) -ForegroundColor Yellow
        }
    }

    if ($needDownload) {
        Write-Host '     开始下载（curl -L --fail --retry 3 -C -）...' -ForegroundColor DarkGray

        & $curlPath '-L' '--fail' '--retry' '3' '-C' '-' '--output' $targetFile $url
        $curlExit = $LASTEXITCODE

        if ($curlExit -ne 0) {
            Write-Host ("     下载失败：curl 退出码 {0}" -f $curlExit) -ForegroundColor Red
            if ($curlExit -eq 33) {
                Write-Host '     提示：服务端不支持断点续传。请删除该文件的半成品后重跑。' -ForegroundColor Red
            } elseif ($curlExit -eq 22) {
                Write-Host '     提示：HTTP 错误（--fail）。检查链接是否有效、网络是否被拦截；可尝试 -HfMirror。' -ForegroundColor Red
            }
            $failed = $failed + 1
            $exitCode = 1
            continue
        }

        if (-not (Test-Path -LiteralPath $targetFile -PathType Leaf)) {
            Write-Host '     错误：下载命令返回成功，但目标文件不存在。' -ForegroundColor Red
            $failed = $failed + 1
            $exitCode = 1
            continue
        }

        $actual = (Get-Item -LiteralPath $targetFile).Length
        if ($actual -ne $m.Size) {
            Write-Host ("     错误：下载后大小不符（实际 {0:N0}，期望 {1:N0} 字节）。" -f $actual, $m.Size) -ForegroundColor Red
            Write-Host '     文件已保留，可直接重跑本脚本继续续传。' -ForegroundColor Red
            $failed = $failed + 1
            $exitCode = 1
            continue
        }

        Write-Host ("     完成：{0:N0} 字节 ({1})" -f $actual, (Format-SizeGiB -Bytes $actual)) -ForegroundColor Green
        $downloaded = $downloaded + 1
    }

    if ($VerifyHash -and (Test-Path -LiteralPath $targetFile -PathType Leaf)) {
        Write-Host '     校验 SHA-256（需要读取整个文件，请耐心等待）...' -ForegroundColor DarkGray
        $actualHash = (Get-FileHash -LiteralPath $targetFile -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -eq $m.Sha256.ToLowerInvariant()) {
            Write-Host '     SHA-256 一致。' -ForegroundColor Green
        } else {
            Write-Host ("     SHA-256 不一致：实际 {0}" -f $actualHash) -ForegroundColor Red
            Write-Host ("     期望 {0}" -f $m.Sha256) -ForegroundColor Red
            Write-Host '     文件可能损坏或来源不同，请删除后重下。' -ForegroundColor Red
            $hashFailed = $hashFailed + 1
            $exitCode = 1
        }
    }

    Write-Host ''
}

# ---------------------------------------------------------------------------
# 汇总
# ---------------------------------------------------------------------------
Write-Host '=== 汇总 ===' -ForegroundColor Cyan
Write-Host ("新下载 : {0}" -f $downloaded)
Write-Host ("已跳过 : {0}" -f $skipped)
Write-Host ("失败   : {0}" -f $failed)
if ($VerifyHash) {
    Write-Host ("哈希不符: {0}" -f $hashFailed)
}
Write-Host ("模型目录: {0}" -f $ResolvedModelsRoot)

if ($exitCode -eq 0) {
    Write-Host '结果：全部就绪。' -ForegroundColor Green
} else {
    Write-Host '结果：存在失败项，见上方错误信息。' -ForegroundColor Red
}
Write-Host ''

exit $exitCode
