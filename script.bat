@echo off
chcp 65001 > nul
mode con cols=120 lines=30 > nul 2>&1
title ดาวน์โหลดเพลงจาก YouTube MP3
echo ===================================================
echo     YouTube Music Downloader & Auto-Sync to MP3
echo ===================================================
echo.

:: ---------------------------------------------------
:: 1. เปิดหน้าต่างตั้งค่า GUI (Playlist URL และ Download Path)
:: ---------------------------------------------------
if not exist "%~dp0gui.ps1" (
    echo กำลังดาวน์โหลด gui.ps1...
    curl.exe -s -L -o "%~dp0gui.ps1" "https://raw.githubusercontent.com/WoodMMK/youtube-music-downloader/main/gui.ps1" 2>nul
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0gui.ps1"
if errorlevel 1 (
    echo.
    echo [!] ยกเลิกการทำงาน
    timeout /t 2 > nul
    exit /b 0
)

:: อ่านการตั้งค่าจาก config.txt
set "PLAYLIST_URL="
set "DOWNLOAD_PATH="
set "ENABLE_SYNC=1"

if exist "%~dp0config.txt" (
    for /f "usebackq tokens=1* delims==" %%A in ("%~dp0config.txt") do (
        if "%%A"=="PLAYLIST_URL" set "PLAYLIST_URL=%%B"
        if "%%A"=="DOWNLOAD_PATH" set "DOWNLOAD_PATH=%%B"
        if "%%A"=="ENABLE_SYNC" set "ENABLE_SYNC=%%B"
    )
)

:: ตรวจสอบความถูกต้องของค่าที่ได้
if "%PLAYLIST_URL%"=="" (
    if exist "%~dp0playlist.txt" set /p PLAYLIST_URL=<"%~dp0playlist.txt"
)

if "%PLAYLIST_URL%"=="" (
    echo [ข้อผิดพลาด] ไม่พบลิงก์ Playlist กรุณาลองใหม่อีกครั้ง
    pause
    exit /b 1
)

if "%DOWNLOAD_PATH%"=="" (
    set "DOWNLOAD_PATH=%USERPROFILE%\Music\YouTubeMusic"
)

echo.
echo ---------------------------------------------------
echo 🔗 ลิงก์ Playlist   : %PLAYLIST_URL%
echo 📁 โฟลเดอร์ปลายทาง : %DOWNLOAD_PATH%
echo 📋 ประวัติการโหลด   : %DOWNLOAD_PATH%\downloaded.txt
echo ---------------------------------------------------
echo 🔍 กำลังตรวจสอบและเริ่มดาวน์โหลด...
echo (เพลงที่เคยโหลดไว้แล้วจะถูกข้ามโดยอัตโนมัติ)
echo ---------------------------------------------------
echo.

:: ---------------------------------------------------
:: 2. ตรวจสอบและดาวน์โหลดเครื่องมืออัตโนมัติหากยังไม่มี (จบในตัวเอง)
:: ---------------------------------------------------
if not exist "%~dp0yt-dlp.exe" (
    echo กำลังดาวน์โหลด yt-dlp.exe อัตโนมัติ...
    curl.exe -L --progress-bar -o "%~dp0yt-dlp.exe" "https://github.com/yt-dlp/yt-dlp-nightly-builds/releases/latest/download/yt-dlp.exe"
    echo.
)

if not exist "%~dp0deno.exe" (
    echo กำลังดาวน์โหลด deno.exe อัตโนมัติ...
    curl.exe -L --progress-bar -o "%~dp0deno.zip" "https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip"
    tar.exe -xf "%~dp0deno.zip" -C "%~dp0" 2>nul
    del "%~dp0deno.zip" >nul 2>&1
    echo.
)

if not exist "%~dp0ffmpeg.exe" (
    echo กำลังดาวน์โหลด ffmpeg.exe อัตโนมัติ - ทำเฉพาะครั้งแรก...
    curl.exe -L --progress-bar -o "%~dp0ffmpeg.zip" "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
    tar.exe --strip-components=2 -xf "%~dp0ffmpeg.zip" "ffmpeg-*-essentials_build/bin/ffmpeg.exe" "ffmpeg-*-essentials_build/bin/ffprobe.exe" 2>nul
    del "%~dp0ffmpeg.zip" >nul 2>&1
    echo.
)

:: ---------------------------------------------------
:: 3. รันคำสั่งดาวน์โหลดเพลง MP3
:: ---------------------------------------------------
set "PATH=%~dp0;%PATH%"
"%~dp0yt-dlp.exe" -x --audio-format mp3 --audio-quality 0 ^
  --embed-metadata --embed-thumbnail ^
  --parse-metadata "%%(artist,uploader)s:%%(meta_album_artist)s" ^
  --parse-metadata "playlist_index:%%(track_number)s" ^
  --convert-thumbnails jpg ^
  --ppa "FFmpeg:-id3v2_version 3" ^
  --windows-filenames ^
  --paths "home:%DOWNLOAD_PATH%" ^
  --paths "temp:%TEMP%/yt-music" ^
  --download-archive "%DOWNLOAD_PATH%/downloaded.txt" ^
  -o "%%(title)s.%%(ext)s" ^
  --console-title ^
  --progress-template "download:[%%(info.playlist_index)s/%%(info.n_entries)s] 🎵 %%(info.title).40s [%%(progress._percent_str)s] ความเร็ว: %%(progress._speed_str)s | เหลืออีก: %%(progress._eta_str)s" ^
  --progress-template "postprocess:[%%(info.playlist_index)s/%%(info.n_entries)s] 🔄 กำลังแปลงไฟล์ MP3 / ใส่ภาพปก: %%(info.title).40s" ^
  --progress-template "download-title:[%%(info.playlist_index)s/%%(info.n_entries)s] %%(progress._percent_str)s - %%(info.title)s" ^
  "%PLAYLIST_URL%"

:: ---------------------------------------------------
:: 4. ตรวจสอบและซิงค์เพลง (True Sync) + เรียงลำดับ Track Number ใหม่
:: ---------------------------------------------------
if "%ENABLE_SYNC%"=="1" (
  echo.
  echo ---------------------------------------------------
  echo 🔄 กำลังตรวจสอบเพลงที่ถูกลบ และเรียงลำดับ Track Number...
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference='SilentlyContinue';" ^
    "$targetDir = '%DOWNLOAD_PATH%'.TrimEnd('\', '/');" ^
    "$currentIds = @(& '%~dp0yt-dlp.exe' --flat-playlist --print id '%PLAYLIST_URL%');" ^
    "$totalTracks = $currentIds.Count;" ^
    "if ($totalTracks -gt 0) {" ^
    "  $archiveFile = Join-Path $targetDir 'downloaded.txt';" ^
    "  $driveRootArchive = Join-Path ([System.IO.Path]::GetPathRoot($targetDir)) 'downloaded.txt';" ^
    "  if (-not (Test-Path -LiteralPath $archiveFile) -and (Test-Path -LiteralPath $driveRootArchive)) { $archiveFile = $driveRootArchive };" ^
    "  if (Test-Path -LiteralPath $archiveFile) {" ^
    "    $archiveLines = Get-Content -LiteralPath $archiveFile;" ^
    "    $archiveIds = $archiveLines | ForEach-Object { if ($_ -match 'youtube\s+(\S+)') { $matches[1] } };" ^
    "    $deletedIds = @($archiveIds | Where-Object { $_ -notin $currentIds });" ^
    "    if ($deletedIds.Count -gt 0) {" ^
    "      Write-Host ('🧹 พบเพลงที่ถูกลบออกจาก Playlist (' + $deletedIds.Count + ' เพลง) กำลังลบออกจากคลังเพลง...') -ForegroundColor Yellow;" ^
    "      $mp3Files = Get-ChildItem -LiteralPath $targetDir -Filter *.mp3;" ^
    "      foreach ($dId in $deletedIds) {" ^
    "        foreach ($f in $mp3Files) {" ^
    "          $probe = & '%~dp0ffprobe.exe' -v quiet -show_entries format_tags=comment,purl -of default=noprint_wrappers=1:nokey=1 $f.FullName;" ^
    "          if (($probe -join ' ') -match [regex]::Escape($dId)) {" ^
    "            Write-Host ('  🗑️ ลบเพลง: ' + $f.Name) -ForegroundColor Red;" ^
    "            Remove-Item -LiteralPath $f.FullName -Force;" ^
    "            break;" ^
    "          }" ^
    "        }" ^
    "      }" ^
    "      $remaining = $archiveLines | Where-Object { $line = $_; $k = $true; foreach ($d in $deletedIds) { if ($line -match [regex]::Escape($d)) { $k = $false; break } }; $k };" ^
    "      Set-Content -LiteralPath $archiveFile -Value $remaining -Encoding UTF8;" ^
    "    } else {" ^
    "      Write-Host '  ✨ คลังเพลงตรงกับ Playlist 100%% (ไม่มีเพลงที่ถูกลบ)' -ForegroundColor Green;" ^
    "    }" ^
    "  }" ^
    "  Write-Host ('🔢 กำลังตรวจสอบและเรียงลำดับ Track Number (1 ถึง ' + $totalTracks + ')...') -ForegroundColor Cyan;" ^
    "  $mp3Files = Get-ChildItem -LiteralPath $targetDir -Filter *.mp3;" ^
    "  $fileMap = @{};" ^
    "  foreach ($f in $mp3Files) {" ^
    "    $probe = & '%~dp0ffprobe.exe' -v quiet -show_entries format_tags=comment,purl -of default=noprint_wrappers=1:nokey=1 $f.FullName;" ^
    "    if (($probe -join ' ') -match 'watch\?v=([a-zA-Z0-9_-]{11})') { $fileMap[$matches[1]] = $f.FullName }" ^
    "  };" ^
    "  $updatedCount = 0;" ^
    "  for ($i = 0; $i -lt $totalTracks; $i++) {" ^
    "    $vid = $currentIds[$i];" ^
    "    $trackNum = $i + 1;" ^
    "    $targetTrack = '' + $trackNum + '/' + $totalTracks;" ^
    "    if ($fileMap.ContainsKey($vid)) {" ^
    "      $fPath = $fileMap[$vid];" ^
    "      $curTrack = & '%~dp0ffprobe.exe' -v quiet -show_entries format_tags=track -of default=noprint_wrappers=1:nokey=1 $fPath;" ^
    "      if ($curTrack -ne $targetTrack) {" ^
    "        $tmp = ($env:TEMP + '\track_tmp_' + $trackNum + '.mp3');" ^
    "        & '%~dp0ffmpeg.exe' -v error -y -i $fPath -c copy -id3v2_version 3 -metadata ('track=' + $targetTrack) $tmp;" ^
    "        if (Test-Path -LiteralPath $tmp) {" ^
    "          Move-Item -LiteralPath $tmp -Destination $fPath -Force;" ^
    "          $updatedCount++;" ^
    "        }" ^
    "      }" ^
    "    }" ^
    "  };" ^
    "  if ($updatedCount -gt 0) {" ^
    "    Write-Host ('  ✨ เรียงลำดับ Track Number ใหม่เรียบร้อย (' + $updatedCount + ' เพลง) [1 ถึง ' + $totalTracks + ']') -ForegroundColor Green;" ^
    "  } else {" ^
    "    Write-Host '  ✨ Track Number ตรงกับลำดับใน Playlist ทุกเพลงอยู่แล้ว' -ForegroundColor Green;" ^
    "  }" ^
    "}"
)

echo.
echo ===================================================
echo  ✅ ดำเนินการเสร็จสิ้น! ทุกเพลงซิงค์ตรงกับ Playlist เรียบร้อย
echo ===================================================
pause
