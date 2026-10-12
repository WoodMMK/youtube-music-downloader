@echo off
chcp 65001 > nul
mode con cols=120 lines=30 > nul 2>&1
title ดาวน์โหลดเพลงจาก YouTube MP3
echo ===================================================
echo       โหลดเพลงจาก YouTube เป็น MP3 ลง Flash Drive
echo ===================================================

:: ---------------------------------------------------
:: 1. วางลิงก์ Playlist ของคุณตรงนี้ (หรือใส่ในไฟล์ playlist.txt)
set "PLAYLIST_URL=YOUR_PLAYLIST_URL_HERE"
if exist "%~dp0playlist.txt" set /p PLAYLIST_URL=<"%~dp0playlist.txt"

if "%PLAYLIST_URL%"=="YOUR_PLAYLIST_URL_HERE" (
    echo [ข้อผิดพลาด] กรุณาระบุลิงก์ YouTube Playlist ก่อนใช้งาน!
    echo สามารถแก้ไขตัวแปร PLAYLIST_URL ใน script.bat หรือสร้างไฟล์ playlist.txt
    echo.
    pause
    exit /b
)
:: ---------------------------------------------------

:: 2. กำหนด Drive Letter สำหรับ Flash Drive (ค่าเริ่มต้นคือ E)
set "DRIVE=E"
:: หากต้องการให้ถาม Drive ทุกครั้ง ให้เอา :: หน้าบรรทัดล่างออก:
:: set /p DRIVE="ระบุ Drive Letter ของ Flash Drive [ค่าเริ่มต้นคือ E]: "

echo.
echo กำลังตรวจสอบและดาวน์โหลดเพลงใหม่...
echo โฟลเดอร์ปลายทาง : %DRIVE%:\Music\
echo ประวัติการโหลด   : %DRIVE%:\downloaded.txt
echo ---------------------------------------------------
echo 🔍 กำลังตรวจสอบ Playlist และเริ่มดาวน์โหลด...
echo (เพลงที่เคยโหลดไว้แล้วจะถูกข้ามโดยอัตโนมัติ)
echo ---------------------------------------------------
echo.

:: ---------------------------------------------------
:: ตรวจสอบและดาวน์โหลดเครื่องมืออัตโนมัติหากยังไม่มี (จบในตัวเอง ไม่ต้องติดตั้งอะไรเพิ่ม)
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

:: รันคำสั่งดาวน์โหลด
set "PATH=%~dp0;%PATH%"
"%~dp0yt-dlp.exe" -x --audio-format mp3 --audio-quality 0 ^
  --embed-metadata --embed-thumbnail ^
  --parse-metadata "%%(artist,uploader)s:%%(meta_album_artist)s" ^
  --parse-metadata "playlist_index:%%(track_number)s" ^
  --convert-thumbnails jpg ^
  --ppa "FFmpeg:-id3v2_version 3" ^
  --windows-filenames ^
  --paths "home:%DRIVE%:/Music" ^
  --paths "temp:%TEMP%/yt-music" ^
  --download-archive "%DRIVE%:/downloaded.txt" ^
  -o "%%(title)s.%%(ext)s" ^
  --console-title ^
  --progress-template "download:[%%(info.playlist_index)s/%%(info.n_entries)s] 🎵 %%(info.title).40s [%%(progress._percent_str)s] ความเร็ว: %%(progress._speed_str)s | เหลืออีก: %%(progress._eta_str)s" ^
  --progress-template "postprocess:[%%(info.playlist_index)s/%%(info.n_entries)s] 🔄 กำลังแปลงไฟล์ MP3 / ใส่ภาพปก: %%(info.title).40s" ^
  --progress-template "download-title:[%%(info.playlist_index)s/%%(info.n_entries)s] %%(progress._percent_str)s - %%(info.title)s" ^
  "%PLAYLIST_URL%"

:: ---------------------------------------------------
:: ตรวจสอบและซิงค์เพลง (True Sync) + เรียงลำดับ Track Number ใหม่
:: ---------------------------------------------------
echo.
echo ---------------------------------------------------
echo 🔄 กำลังตรวจสอบเพลงที่ถูกลบ และเรียงลำดับ Track Number...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='SilentlyContinue';" ^
  "$currentIds = @(& '%~dp0yt-dlp.exe' --flat-playlist --print id '%PLAYLIST_URL%');" ^
  "$totalTracks = $currentIds.Count;" ^
  "if ($totalTracks -gt 0) {" ^
  "  $archiveFile = '%DRIVE%:\downloaded.txt';" ^
  "  if (Test-Path -LiteralPath $archiveFile) {" ^
  "    $archiveLines = Get-Content -LiteralPath $archiveFile;" ^
  "    $archiveIds = $archiveLines | ForEach-Object { if ($_ -match 'youtube\s+(\S+)') { $matches[1] } };" ^
  "    $deletedIds = @($archiveIds | Where-Object { $_ -notin $currentIds });" ^
  "    if ($deletedIds.Count -gt 0) {" ^
  "      Write-Host ('🧹 พบเพลงที่ถูกลบออกจาก Playlist (' + $deletedIds.Count + ' เพลง) กำลังลบออกจาก Flash Drive...') -ForegroundColor Yellow;" ^
  "      $mp3Files = Get-ChildItem -LiteralPath '%DRIVE%:\Music\' -Filter *.mp3;" ^
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
  "  $mp3Files = Get-ChildItem -LiteralPath '%DRIVE%:\Music\' -Filter *.mp3;" ^
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

echo.
echo ===================================================
echo  ✅ ดำเนินการเสร็จสิ้น! ทุกเพลงใน Flash Drive ซิงค์ตรงกับ Playlist เรียบร้อย
echo ===================================================
pause