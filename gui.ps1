# GUI Setup Dialog for YouTube Music Downloader
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }
$configFile = Join-Path $scriptDir "config.txt"
$legacyPlaylistFile = Join-Path $scriptDir "playlist.txt"

# 1. Load existing settings
$savedUrl = ""
$savedPath = ""
$savedSync = $true

if (Test-Path -LiteralPath $configFile) {
    Get-Content -LiteralPath $configFile | ForEach-Object {
        if ($_ -match '^\s*PLAYLIST_URL=(.*)$') { $savedUrl = $matches[1].Trim() }
        if ($_ -match '^\s*DOWNLOAD_PATH=(.*)$') { $savedPath = $matches[1].Trim() }
        if ($_ -match '^\s*ENABLE_SYNC=(.*)$') { $savedSync = ($matches[1].Trim() -ne "0") }
    }
}

# If URL is still empty, check legacy playlist.txt
if ([string]::IsNullOrWhiteSpace($savedUrl) -or $savedUrl -eq "YOUR_PLAYLIST_URL_HERE") {
    if (Test-Path -LiteralPath $legacyPlaylistFile) {
        $firstLine = (Get-Content -LiteralPath $legacyPlaylistFile -TotalCount 1).Trim()
        if ($firstLine -and $firstLine -ne "YOUR_PLAYLIST_URL_HERE") {
            $savedUrl = $firstLine
        }
    }
}

# Auto-detect from Clipboard if URL is empty
if ([string]::IsNullOrWhiteSpace($savedUrl) -or $savedUrl -eq "YOUR_PLAYLIST_URL_HERE") {
    try {
        $clip = [System.Windows.Forms.Clipboard]::GetText()
        if ($clip -match '^https?://(www\.)?(youtube\.com|youtu\.be)/') {
            $savedUrl = $clip.Trim()
        }
    } catch {}
}

# Auto-detect default Download Path if empty
if ([string]::IsNullOrWhiteSpace($savedPath)) {
    # Try Removable USB Drive first
    try {
        $usb = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -eq 'Removable' -and $_.DriveLetter } | Select-Object -First 1
        if ($usb) {
            $savedPath = "$($usb.DriveLetter):\Music"
        }
    } catch {}

    # Try Drive E: if present
    if ([string]::IsNullOrWhiteSpace($savedPath) -and (Test-Path "E:\")) {
        $savedPath = "E:\Music"
    }

    # Fallback to User Music folder
    if ([string]::IsNullOrWhiteSpace($savedPath)) {
        $musicFolder = [Environment]::GetFolderPath('MyMusic')
        if (-not $musicFolder) { $musicFolder = [System.IO.Path]::Combine($env:USERPROFILE, "Music") }
        $savedPath = Join-Path $musicFolder "YouTubeMusic"
    }
}

# ----------------- Create Form -----------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "YouTube Music Downloader & Auto-Sync"
$form.Size = New-Object System.Drawing.Size(600, 310)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$form.BackColor = [System.Drawing.Color]::FromArgb(248, 249, 250)

# Header
$lblHeader = New-Object System.Windows.Forms.Label
$lblHeader.Text = "🎵 ตั้งค่าการดาวน์โหลดเพลงจาก YouTube Playlist"
$lblHeader.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$lblHeader.ForeColor = [System.Drawing.Color]::FromArgb(33, 37, 41)
$lblHeader.Location = New-Object System.Drawing.Point(22, 14)
$lblHeader.AutoSize = $true
$form.Controls.Add($lblHeader)

# Label 1: Playlist URL
$lblUrl = New-Object System.Windows.Forms.Label
$lblUrl.Text = "🔗 ลิงก์ YouTube Playlist:"
$lblUrl.Location = New-Object System.Drawing.Point(22, 48)
$lblUrl.AutoSize = $true
$form.Controls.Add($lblUrl)

# TextBox 1: Playlist URL
$txtUrl = New-Object System.Windows.Forms.TextBox
$txtUrl.Location = New-Object System.Drawing.Point(24, 72)
$txtUrl.Size = New-Object System.Drawing.Size(536, 26)
$txtUrl.Text = $savedUrl
$form.Controls.Add($txtUrl)

# Label 2: Download Path
$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Text = "📁 โฟลเดอร์ปลายทาง (Download Path - บันทึกลงเครื่อง หรือ Flash Drive ได้):"
$lblPath.Location = New-Object System.Drawing.Point(22, 110)
$lblPath.AutoSize = $true
$form.Controls.Add($lblPath)

# TextBox 2: Download Path
$txtPath = New-Object System.Windows.Forms.TextBox
$txtPath.Location = New-Object System.Drawing.Point(24, 134)
$txtPath.Size = New-Object System.Drawing.Size(410, 26)
$txtPath.Text = $savedPath
$form.Controls.Add($txtPath)

# Button Browse
$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "📂 เลือกโฟลเดอร์..."
$btnBrowse.Location = New-Object System.Drawing.Point(442, 132)
$btnBrowse.Size = New-Object System.Drawing.Size(118, 29)
$btnBrowse.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "เลือกโฟลเดอร์ปลายทางสำหรับบันทึกไฟล์เพลง MP3"
    if (Test-Path -LiteralPath $txtPath.Text) { $dlg.SelectedPath = $txtPath.Text }
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtPath.Text = $dlg.SelectedPath
    }
})
$form.Controls.Add($btnBrowse)

# CheckBox Sync
$chkSync = New-Object System.Windows.Forms.CheckBox
$chkSync.Text = "🔄 ซิงค์คลังเพลง (True Sync: ลบเพลงที่ถูกคัดออกจาก Playlist อัตโนมัติ)"
$chkSync.Location = New-Object System.Drawing.Point(24, 175)
$chkSync.Size = New-Object System.Drawing.Size(536, 24)
$chkSync.Checked = $savedSync
$form.Controls.Add($chkSync)

# Action Buttons Panel
$pnlButtons = New-Object System.Windows.Forms.Panel
$pnlButtons.Location = New-Object System.Drawing.Point(0, 215)
$pnlButtons.Size = New-Object System.Drawing.Size(600, 65)
$pnlButtons.BackColor = [System.Drawing.Color]::FromArgb(238, 240, 242)

# Button Cancel
$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "ยกเลิก"
$btnCancel.Location = New-Object System.Drawing.Point(460, 14)
$btnCancel.Size = New-Object System.Drawing.Size(100, 34)
$btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$pnlButtons.Controls.Add($btnCancel)

# Button Start
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "🚀 เริ่มดาวน์โหลด"
$btnStart.Location = New-Object System.Drawing.Point(300, 14)
$btnStart.Size = New-Object System.Drawing.Size(150, 34)
$btnStart.BackColor = [System.Drawing.Color]::FromArgb(13, 110, 253)
$btnStart.ForeColor = [System.Drawing.Color]::White
$btnStart.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnStart.FlatAppearance.BorderSize = 0
$btnStart.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$btnStart.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnStart.Add_Click({
    $urlInput = $txtUrl.Text.Trim()
    $pathInput = $txtPath.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($urlInput) -or $urlInput -eq "YOUR_PLAYLIST_URL_HERE") {
        [System.Windows.Forms.MessageBox]::Show("กรุณาระบุลิงก์ YouTube Playlist ก่อนเริ่มดาวน์โหลด", "แจ้งเตือน", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    if ([string]::IsNullOrWhiteSpace($pathInput)) {
        [System.Windows.Forms.MessageBox]::Show("กรุณาระบุโฟลเดอร์ปลายทางสำหรับดาวน์โหลดเพลง", "แจ้งเตือน", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    # Ensure folder exists
    try {
        if (-not (Test-Path -LiteralPath $pathInput)) {
            [void](New-Item -ItemType Directory -Path $pathInput -Force)
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("ไม่สามารถสร้างหรือเข้าถึงโฟลเดอร์ปลายทางได้:`n$($_.Exception.Message)", "ข้อผิดพลาด", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    # 1. Update legacy playlist.txt (retains exact backwards compatibility)
    try {
        Set-Content -LiteralPath $legacyPlaylistFile -Value $urlInput -Encoding UTF8
    } catch {}

    # 2. Update config.txt
    $syncVal = if ($chkSync.Checked) { "1" } else { "0" }
    $cfgContent = @(
        "PLAYLIST_URL=$urlInput"
        "DOWNLOAD_PATH=$pathInput"
        "ENABLE_SYNC=$syncVal"
    )
    Set-Content -LiteralPath $configFile -Value $cfgContent -Encoding UTF8

    $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Close()
})
$pnlButtons.Controls.Add($btnStart)

$form.Controls.Add($pnlButtons)
$form.AcceptButton = $btnStart
$form.CancelButton = $btnCancel

# Show Form
$result = $form.ShowDialog()

if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    exit 0
} else {
    exit 1
}
