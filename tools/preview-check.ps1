param(
    [int]$Port = 4173,
    [int]$Width = 1280,
    [int]$Height = 720,
    [switch]$UpdateBaseline
)

$root = Split-Path -Parent $PSScriptRoot
$previewDir = Join-Path $root "previews"
$null = New-Item -ItemType Directory -Force -Path $previewDir

$edge = (Get-Command msedge -ErrorAction SilentlyContinue).Source
if (-not $edge) {
    $edge = Join-Path ${env:ProgramFiles(x86)} "Microsoft\Edge\Application\msedge.exe"
    if (-not (Test-Path $edge)) {
        $edge = Join-Path $env:ProgramFiles "Microsoft\Edge\Application\msedge.exe"
    }
}
if (-not (Test-Path $edge)) {
    throw "Microsoft Edge not found. Install Edge or update the script with the browser path."
}

$python = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $python) {
    $python = (Get-Command py -ErrorAction SilentlyContinue).Source
}
if (-not $python) {
    throw "python/py not found. Install Python or adjust the script to use another local server."
}

$shot = Join-Path $previewDir "current.png"
$baseline = Join-Path $previewDir "baseline.png"
$diff = Join-Path $previewDir "diff.png"
$url = "http://127.0.0.1:$Port/index.html?snapshot=1"

$server = $null
try {
    $server = Start-Process -FilePath $python -ArgumentList "-m","http.server",$Port,"--bind","127.0.0.1" -WorkingDirectory $root -PassThru -WindowStyle Hidden
    Start-Sleep -Milliseconds 600

    & $edge "--headless" "--disable-gpu" "--window-size=$Width,$Height" "--screenshot=$shot" $url | Out-Null
} finally {
    if ($server -and -not $server.HasExited) {
        Stop-Process -Id $server.Id -Force
    }
}

if ($UpdateBaseline) {
    Copy-Item -Force $shot $baseline
    Write-Host "Baseline updated: $baseline"
    exit 0
}

if (Test-Path $baseline) {
    $magick = (Get-Command magick -ErrorAction SilentlyContinue).Source
    if ($magick) {
        $metric = & $magick compare -metric AE $baseline $shot $diff 2>&1
        Write-Host "Pixel diff (AE): $metric"
        Write-Host "Diff image: $diff"
        exit 0
    } else {
        $baseHash = (Get-FileHash $baseline).Hash
        $shotHash = (Get-FileHash $shot).Hash
        if ($baseHash -eq $shotHash) {
            Write-Host "No change detected (hash match)."
        } else {
            Write-Host "Change detected (hash mismatch)."
        }
        Write-Host "Current: $shot"
        exit 0
    }
}

Write-Host "No baseline found. Run with -UpdateBaseline to set one."
Write-Host "Current: $shot"
