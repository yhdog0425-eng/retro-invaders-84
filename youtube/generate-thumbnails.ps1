# =====================================================================
#  レトロインベーダー84 サムネイル／OGP画像 生成スクリプト
#
#  実行方法（PowerShell でこのファイルがあるフォルダーから）:
#      powershell -ExecutionPolicy Bypass -File .\generate-thumbnails.ps1
#
#  出力:
#      ..\ogp.png                 1200x630   SNS共有用（OGP）
#      .\thumbnail-wide.png       1280x720   YouTube通常動画のサムネイル
#      .\thumbnail-shorts.png     1080x1920  YouTubeショートのカバー
# =====================================================================

Add-Type -AssemblyName System.Drawing

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here

# ---- 配色（ゲーム画面と統一） ----
$CGreen  = [System.Drawing.Color]::FromArgb(255, 141, 255, 158)
$CGreenD = [System.Drawing.Color]::FromArgb(255, 108, 255, 142)
$CBlue   = [System.Drawing.Color]::FromArgb(255, 123, 214, 255)
$CPink   = [System.Drawing.Color]::FromArgb(255, 255, 107, 139)
$CYellow = [System.Drawing.Color]::FromArgb(255, 255, 224, 102)
$CInk    = [System.Drawing.Color]::FromArgb(255, 5, 6, 10)
$CGray   = [System.Drawing.Color]::FromArgb(255, 150, 190, 160)

# ---- ドット絵（index.html と同じ定義） ----
$SP_OCTO = @(
  ".....##.....",
  "...######...",
  "..########..",
  ".##.####.##.",
  "############",
  "..###..###..",
  ".##......##.",
  "..##....##..")
$SP_SQUID = @(
  "....##....",
  "...####...",
  "..######..",
  ".##.##.##.",
  "..######..",
  "....##....",
  "...#..#...",
  "..#....#..")
$SP_CRAB = @(
  "..#.....#..",
  "...#...#...",
  "..#######..",
  ".##.###.##.",
  "###########",
  "#.#######.#",
  "#.#.....#.#",
  "...##.##...")
$SP_SHIP = @(
  ".....#.....",
  "....###....",
  "....###....",
  "###########",
  "###########",
  "###########",
  "###########",
  "##.......##")

function Get-JpFont {
    param([single]$Size, [System.Drawing.FontStyle]$Style = [System.Drawing.FontStyle]::Bold)
    foreach ($name in @('Yu Gothic UI', 'Meiryo', 'Yu Gothic', 'MS Gothic', 'Arial')) {
        try {
            $f = New-Object System.Drawing.Font($name, $Size, $Style, [System.Drawing.GraphicsUnit]::Pixel)
            if ($f.Name -eq $name) { return $f }
            $f.Dispose()
        } catch { }
    }
    return New-Object System.Drawing.Font('Arial', $Size, $Style, [System.Drawing.GraphicsUnit]::Pixel)
}

function Draw-Sprite {
    param($G, [string[]]$Rows, [single]$X, [single]$Y, [single]$Px, [System.Drawing.Color]$Color)
    $b = New-Object System.Drawing.SolidBrush($Color)
    for ($r = 0; $r -lt $Rows.Count; $r++) {
        $line = $Rows[$r]
        for ($c = 0; $c -lt $line.Length; $c++) {
            if ($line[$c] -eq '#') {
                $G.FillRectangle($b, [single]($X + $c * $Px), [single]($Y + $r * $Px), [single]$Px, [single]$Px)
            }
        }
    }
    $b.Dispose()
}

function Get-SpriteWidth { param([string[]]$Rows, [single]$Px) return [single]($Rows[0].Length * $Px) }

# 中央揃えでテキストを描く（グロー付き）
function Draw-CenterText {
    param($G, [string]$Text, [single]$CenterX, [single]$Y, $Font, [System.Drawing.Color]$Color, [System.Drawing.Color]$Glow, [int]$GlowSize = 0)
    $sz = $G.MeasureString($Text, $Font)
    $x = $CenterX - $sz.Width / 2
    if ($GlowSize -gt 0) {
        $gb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(38, $Glow.R, $Glow.G, $Glow.B))
        for ($i = 1; $i -le $GlowSize; $i++) {
            $o = [single]($i * 2)
            $G.DrawString($Text, $Font, $gb, [single]($x - $o), [single]$Y)
            $G.DrawString($Text, $Font, $gb, [single]($x + $o), [single]$Y)
            $G.DrawString($Text, $Font, $gb, [single]$x, [single]($Y - $o))
            $G.DrawString($Text, $Font, $gb, [single]$x, [single]($Y + $o))
        }
        $gb.Dispose()
    }
    $b = New-Object System.Drawing.SolidBrush($Color)
    $G.DrawString($Text, $Font, $b, [single]$x, [single]$Y)
    $b.Dispose()
    return $sz
}

# 塗りつぶしバッジ（角丸なしのベタ帯）
function Draw-Badge {
    param($G, [string]$Text, [single]$CenterX, [single]$Y, $Font, [System.Drawing.Color]$Bg, [System.Drawing.Color]$Fg, [single]$PadX, [single]$PadY)
    $sz = $G.MeasureString($Text, $Font)
    $w = $sz.Width + $PadX * 2
    $h = $sz.Height + $PadY * 2
    $x = $CenterX - $w / 2
    $bb = New-Object System.Drawing.SolidBrush($Bg)
    $G.FillRectangle($bb, [single]$x, [single]$Y, [single]$w, [single]$h)
    $bb.Dispose()
    $fb = New-Object System.Drawing.SolidBrush($Fg)
    $G.DrawString($Text, $Font, $fb, [single]($x + $PadX), [single]($Y + $PadY))
    $fb.Dispose()
    return $h
}

function New-Thumbnail {
    param([int]$Width, [int]$Height, [string]$OutPath, [string]$Layout)

    $bmp = New-Object System.Drawing.Bitmap($Width, $Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor

    # 背景
    $bg = New-Object System.Drawing.SolidBrush($CInk)
    $g.FillRectangle($bg, 0, 0, $Width, $Height)
    $bg.Dispose()

    # 中央上部の緑グロー
    $cx = [single]($Width / 2)
    $glowY = [single]($Height * 0.30)
    for ($i = 14; $i -ge 1; $i--) {
        $rad = [single]($Width * 0.10 * $i / 3)
        $a = [int](3 + (14 - $i))
        $gb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($a, 20, 120, 60))
        $g.FillEllipse($gb, [single]($cx - $rad), [single]($glowY - $rad * 0.6), [single]($rad * 2), [single]($rad * 1.2))
        $gb.Dispose()
    }

    # 星
    $sb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(40, 255, 255, 255))
    $rnd = New-Object System.Random(84)
    for ($i = 0; $i -lt 140; $i++) {
        $sx = $rnd.Next(0, $Width); $sy = $rnd.Next(0, $Height)
        $ss = $rnd.Next(1, 4)
        $g.FillRectangle($sb, [single]$sx, [single]$sy, [single]$ss, [single]$ss)
    }
    $sb.Dispose()

    if ($Layout -eq 'portrait') {
        $px      = 12
        $rowY    = [single]($Height * 0.15)
        $titleY  = [single]($Height * 0.29)
        $titleSz = 118
        $subY    = [single]($Height * 0.415)
        $subSz   = 54
        $badgeY  = [single]($Height * 0.50)
        $badgeSz = 46
        $shipY   = [single]($Height * 0.62)
        $shipPx  = 14
        $urlY    = [single]($Height * 0.76)
        $urlSz   = 40
        $foot    = 'ブラウザーで無料であそべる'
        $footSz  = 42
        $footY   = [single]($Height * 0.86)
    } else {
        $px      = [int]([Math]::Round($Height / 90))
        $rowY    = [single]($Height * 0.11)
        $titleY  = [single]($Height * 0.30)
        $titleSz = [int]($Height * 0.155)
        $subY    = [single]($Height * 0.520)
        $subSz   = [int]($Height * 0.062)
        $badgeY  = [single]($Height * 0.620)
        $badgeSz = [int]($Height * 0.050)
        $shipY   = [single]($Height * 0.800)
        $shipPx  = [int]([Math]::Round($Height / 80))
        $urlY    = [single]($Height * 0.930)
        $urlSz   = [int]($Height * 0.040)
        $foot    = $null
        $footSz  = 0
        $footY   = 0
    }

    # --- インベーダー3体 ---
    $w1 = Get-SpriteWidth $SP_OCTO  $px
    $w2 = Get-SpriteWidth $SP_SQUID $px
    $w3 = Get-SpriteWidth $SP_CRAB  $px
    $gap = [single]($px * 5)
    $totalW = $w1 + $w2 + $w3 + $gap * 2
    $sx = $cx - $totalW / 2
    Draw-Sprite $g $SP_OCTO  $sx $rowY $px $CPink
    Draw-Sprite $g $SP_SQUID ([single]($sx + $w1 + $gap)) $rowY $px $CBlue
    Draw-Sprite $g $SP_CRAB  ([single]($sx + $w1 + $gap + $w2 + $gap)) $rowY $px $CGreen

    # --- タイトル（クリックの動機は「懐かしいゲーム」ではなく「AIと作った」）---
    $fTitle = Get-JpFont $titleSz
    Draw-CenterText $g 'AIと作った' $cx $titleY $fTitle $CGreenD $CGreenD 6 | Out-Null
    $fTitle.Dispose()

    # --- サブタイトル ---
    $fSub = Get-JpFont $subSz ([System.Drawing.FontStyle]::Regular)
    Draw-CenterText $g 'レトロインベーダー84' $cx $subY $fSub $CGray $CGreenD 0 | Out-Null
    $fSub.Dispose()

    # --- バッジ ---
    $fBadge = Get-JpFont $badgeSz
    Draw-Badge $g 'プログラム未経験・50代' $cx $badgeY $fBadge $CYellow $CInk ([single]($badgeSz * 0.7)) ([single]($badgeSz * 0.28)) | Out-Null
    $fBadge.Dispose()

    # --- 自機と弾 ---
    $shipW = Get-SpriteWidth $SP_SHIP $shipPx
    $shipX = $cx - $shipW / 2
    Draw-Sprite $g $SP_SHIP $shipX $shipY $shipPx $CGreen
    $wb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    for ($i = 1; $i -le 3; $i++) {
        $g.FillRectangle($wb, [single]($cx - $shipPx / 2), [single]($shipY - $i * $shipPx * 3.2), [single]$shipPx, [single]($shipPx * 2))
    }
    $wb.Dispose()

    # --- URL ---
    $fUrl = Get-JpFont $urlSz ([System.Drawing.FontStyle]::Regular)
    Draw-CenterText $g 'yhdog0425-eng.github.io/invader' $cx $urlY $fUrl $CYellow $CYellow 0 | Out-Null
    $fUrl.Dispose()

    if ($foot) {
        $fFoot = Get-JpFont $footSz
        Draw-CenterText $g $foot $cx $footY $fFoot $CGreenD $CGreenD 3 | Out-Null
        $fFoot.Dispose()
    }

    # 外枠
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 29, 77, 43), [single]([Math]::Max(3, $Height / 200)))
    $g.DrawRectangle($pen, 2, 2, $Width - 5, $Height - 5)
    $pen.Dispose()

    $g.Dispose()
    $bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "作成: $OutPath ($Width x $Height)"
}

New-Thumbnail -Width 1280 -Height 720  -OutPath (Join-Path $here 'thumbnail-wide.png')   -Layout 'landscape'
New-Thumbnail -Width 1200 -Height 630  -OutPath (Join-Path $root 'ogp.png')              -Layout 'landscape'
New-Thumbnail -Width 1080 -Height 1920 -OutPath (Join-Path $here 'thumbnail-shorts.png') -Layout 'portrait'

Write-Host ''
Write-Host '完了しました。YouTubeのサムネイルには thumbnail-wide.png を設定してください。'
