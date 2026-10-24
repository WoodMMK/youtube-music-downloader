@echo off
chcp 65001 > nul
mode con cols=120 lines=30 > nul 2>&1
title YouTube Music Downloader and Auto-Sync
echo ===================================================
echo     YouTube Music Downloader and Auto-Sync
echo ===================================================
echo.

set "ROOT_DIR=%~dp0"
set "BIN_DIR=%~dp0bin"
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"

:: ---------------------------------------------------
:: 1. Open GUI Configuration Dialog
:: ---------------------------------------------------
echo Configuring download settings...

if not exist "%BIN_DIR%\gui.ps1" (
    echo Downloading gui.ps1...
    curl.exe -s -L -o "%BIN_DIR%\gui.ps1" "https://raw.githubusercontent.com/WoodMMK/youtube-music-downloader/main/bin/gui.ps1" 2>nul
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%BIN_DIR%\gui.ps1"
if errorlevel 1 (
    echo.
    echo Operation cancelled by user.
    timeout /t 2 > nul
    exit /b 0
)

:: Read configuration
set "PLAYLIST_URL="
set "DOWNLOAD_PATH="
set "ENABLE_SYNC=1"

if exist "%BIN_DIR%\config.txt" (
    for /f "usebackq tokens=1* delims==" %%A in ("%BIN_DIR%\config.txt") do (
        if "%%A"=="PLAYLIST_URL" set "PLAYLIST_URL=%%B"
        if "%%A"=="DOWNLOAD_PATH" set "DOWNLOAD_PATH=%%B"
        if "%%A"=="ENABLE_SYNC" set "ENABLE_SYNC=%%B"
    )
) else if exist "%ROOT_DIR%config.txt" (
    for /f "usebackq tokens=1* delims==" %%A in ("%ROOT_DIR%config.txt") do (
        if "%%A"=="PLAYLIST_URL" set "PLAYLIST_URL=%%B"
        if "%%A"=="DOWNLOAD_PATH" set "DOWNLOAD_PATH=%%B"
        if "%%A"=="ENABLE_SYNC" set "ENABLE_SYNC=%%B"
    )
)

:: Validate configuration
if "%PLAYLIST_URL%"=="" (
    echo Error: Playlist URL is empty. Please try again.
    pause
    exit /b 1
)

if "%DOWNLOAD_PATH%"=="" (
    set "DOWNLOAD_PATH=%USERPROFILE%\Music\YouTubeMusic"
)

echo.
echo ---------------------------------------------------
echo Playlist URL  : %PLAYLIST_URL%
echo Download Path : %DOWNLOAD_PATH%
echo Download Log  : %DOWNLOAD_PATH%\downloaded.txt
echo ---------------------------------------------------
echo Checking playlist and starting download...
echo Previously downloaded songs will be skipped.
echo ---------------------------------------------------
echo.

:: ---------------------------------------------------
:: 2. Auto-download required tools if missing
:: ---------------------------------------------------
if not exist "%BIN_DIR%\yt-dlp.exe" (
    echo Downloading yt-dlp.exe...
    curl.exe -L --progress-bar -o "%BIN_DIR%\yt-dlp.exe" "https://github.com/yt-dlp/yt-dlp-nightly-builds/releases/latest/download/yt-dlp.exe"
    echo.
)

if not exist "%BIN_DIR%\deno.exe" (
    echo Downloading deno.exe...
    curl.exe -L --progress-bar -o "%BIN_DIR%\deno.zip" "https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip"
    tar.exe -xf "%BIN_DIR%\deno.zip" -C "%BIN_DIR%" 2>nul
    del "%BIN_DIR%\deno.zip" >nul 2>&1
    echo.
)

if not exist "%BIN_DIR%\ffmpeg.exe" (
    echo Downloading ffmpeg.exe - first run only...
    curl.exe -L --progress-bar -o "%BIN_DIR%\ffmpeg.zip" "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
    tar.exe --strip-components=2 -xf "%BIN_DIR%\ffmpeg.zip" "ffmpeg-*-essentials_build/bin/ffmpeg.exe" "ffmpeg-*-essentials_build/bin/ffprobe.exe" -C "%BIN_DIR%" 2>nul
    del "%BIN_DIR%\ffmpeg.zip" >nul 2>&1
    echo.
)

:: ---------------------------------------------------
:: 3. Execute download and MP3 conversion
:: ---------------------------------------------------
set "PATH=%BIN_DIR%;%PATH%"
"%BIN_DIR%\yt-dlp.exe" -x --audio-format mp3 --audio-quality 0 ^
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
  --no-warnings ^
  --console-title ^
  --print "before_dl:[%%(playlist_index)s/%%(n_entries)s] %%(title)s" ^
  "%PLAYLIST_URL%"

:: ---------------------------------------------------
:: 4. True Sync and Track Number Sequencing
:: ---------------------------------------------------
if "%ENABLE_SYNC%"=="1" (
  echo.
  echo ---------------------------------------------------
  echo Checking for deleted songs and re-ordering track numbers...
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference='SilentlyContinue';" ^
    "$targetDir = '%DOWNLOAD_PATH%'.TrimEnd('\', '/');" ^
    "$binDir = '%BIN_DIR%';" ^
    "$currentIds = @(& (Join-Path $binDir 'yt-dlp.exe') --flat-playlist --print id '%PLAYLIST_URL%');" ^
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
    "      Write-Host ('Found deleted songs: ' + $deletedIds.Count + ' tracks. Removing from destination folder...') -ForegroundColor Yellow;" ^
    "      $mp3Files = Get-ChildItem -LiteralPath $targetDir -Filter *.mp3;" ^
    "      foreach ($dId in $deletedIds) {" ^
    "        foreach ($f in $mp3Files) {" ^
    "          $probe = & (Join-Path $binDir 'ffprobe.exe') -v quiet -show_entries format_tags=comment,purl -of default=noprint_wrappers=1:nokey=1 $f.FullName;" ^
    "          if (($probe -join ' ') -match [regex]::Escape($dId)) {" ^
    "            Write-Host ('  Removed track: ' + $f.Name) -ForegroundColor Red;" ^
    "            Remove-Item -LiteralPath $f.FullName -Force;" ^
    "            break;" ^
    "          }" ^
    "        }" ^
    "      }" ^
    "      $remaining = $archiveLines | Where-Object { $line = $_; $k = $true; foreach ($d in $deletedIds) { if ($line -match [regex]::Escape($d)) { $k = $false; break } }; $k };" ^
    "      Set-Content -LiteralPath $archiveFile -Value $remaining -Encoding UTF8;" ^
    "    } else {" ^
    "      Write-Host '  Destination folder matches playlist. No deleted songs found.' -ForegroundColor Green;" ^
    "    }" ^
    "  }" ^
    "  Write-Host ('Checking and re-ordering track numbers from 1 to ' + $totalTracks + '...') -ForegroundColor Cyan;" ^
    "  $mp3Files = Get-ChildItem -LiteralPath $targetDir -Filter *.mp3;" ^
    "  $fileMap = @{};" ^
    "  foreach ($f in $mp3Files) {" ^
    "    $probe = & (Join-Path $binDir 'ffprobe.exe') -v quiet -show_entries format_tags=comment,purl -of default=noprint_wrappers=1:nokey=1 $f.FullName;" ^
    "    if (($probe -join ' ') -match 'watch\?v=([a-zA-Z0-9_-]{11})') { $fileMap[$matches[1]] = $f.FullName }" ^
    "  };" ^
    "  $updatedCount = 0;" ^
    "  for ($i = 0; $i -lt $totalTracks; $i++) {" ^
    "    $vid = $currentIds[$i];" ^
    "    $trackNum = $i + 1;" ^
    "    $targetTrack = '' + $trackNum + '/' + $totalTracks;" ^
    "    if ($fileMap.ContainsKey($vid)) {" ^
    "      $fPath = $fileMap[$vid];" ^
    "      $curTrack = & (Join-Path $binDir 'ffprobe.exe') -v quiet -show_entries format_tags=track -of default=noprint_wrappers=1:nokey=1 $fPath;" ^
    "      if ($curTrack -ne $targetTrack) {" ^
    "        $tmp = ($env:TEMP + '\track_tmp_' + $trackNum + '.mp3');" ^
    "        & (Join-Path $binDir 'ffmpeg.exe') -v error -y -i $fPath -c copy -id3v2_version 3 -metadata ('track=' + $targetTrack) $tmp;" ^
    "        if (Test-Path -LiteralPath $tmp) {" ^
    "          Move-Item -LiteralPath $tmp -Destination $fPath -Force;" ^
    "          $updatedCount++;" ^
    "        }" ^
    "      }" ^
    "    }" ^
    "  };" ^
    "  if ($updatedCount -gt 0) {" ^
    "    Write-Host ('  Track numbers re-ordered successfully for ' + $updatedCount + ' tracks.') -ForegroundColor Green;" ^
    "  } else {" ^
    "    Write-Host '  Track numbers are already in correct order.' -ForegroundColor Green;" ^
    "  }" ^
    "}"
)

echo.
echo ===================================================
echo   Process complete. All tracks are synchronized.
echo ===================================================
pause
