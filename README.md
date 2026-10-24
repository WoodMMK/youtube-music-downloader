# YouTube Music Downloader and Auto-Sync

A batch and PowerShell automation script to download YouTube playlists as high quality MP3 files, embed metadata and cover art, re-order track numbers to match playlist order, and automatically remove deleted songs.

[![Download ZIP](https://img.shields.io/badge/Download-ZIP%20Archive-brightgreen?style=for-the-badge&logo=windows)](https://github.com/WoodMMK/youtube-music-downloader/archive/refs/heads/main.zip)

---

## Features

- Graphical Setup Window: A native configuration dialog opens on launch to provide the playlist URL and select the destination folder. No manual file editing required.
- Automatic Clipboard Detection: Automatically detects and pastes YouTube playlist links from the clipboard.
- Custom Destination Folder: Choose any target folder on local drives or removable USB flash drives using the native folder browser.
- Zero Setup: Automatically downloads yt-dlp, ffmpeg, and deno into the bin folder on first run. No manual tool installation needed.
- Best Audio Quality: Converts audio to high quality MP3 using VBR 0 at 320 kbps.
- Embedded Cover Art and Metadata: Converts thumbnails to JPG and embeds ID3v2.3 tags with artist, title, and album info.
- True Sync: Skips previously downloaded songs and deletes songs locally if they were removed from the YouTube playlist.
- Automatic Track Numbering: Re-indexes ID3 track numbers from 1 to total tracks to ensure car stereos and media players play songs in exact playlist sequence.

---

## Requirements

- Operating System: Windows 10 or Windows 11 with built-in curl, tar, and PowerShell.
- Network: Active internet connection.

---

## Setup and Usage Guide

### 1. Download the Project
Download the ZIP archive using the badge link above, or clone this repository:
```bash
git clone https://github.com/WoodMMK/youtube-music-downloader.git
```

### 2. Extract Archive
Extract the downloaded ZIP file to any folder on your computer.

### 3. Launch and Configure
Double click Start.bat to begin.

You can configure your download settings in two ways:

#### Method 1 - Graphical Setup Dialog
1. The setup window appears automatically on launch.
2. Paste your YouTube playlist URL, or let the dialog auto-fill it from your clipboard.
3. Click Browse to select your destination folder on your computer or USB flash drive.
4. Choose whether to enable True Sync to remove deleted tracks.
5. Click Start Download or press Enter.

#### Method 2 - Direct Configuration File
For headless environments or direct configuration without the setup window, create or edit bin/config.txt:
```text
PLAYLIST_URL=https://www.youtube.com/playlist?list=YOUR_PLAYLIST_ID
DOWNLOAD_PATH=C:\Users\username\Music\YouTubeMusic
ENABLE_SYNC=1
```

Settings are saved in bin/config.txt and will be remembered on subsequent runs.

---

## Project Structure

```text
youtube-music-downloader/
├── Start.bat                # Main launcher - double click to run
├── bin/                     # Internal tools, scripts, and local config
│   ├── gui.ps1
│   └── config.txt           # Created automatically on first run
├── .gitignore               # Excludes binary files and local configs
└── README.md                # Documentation
```

Binaries and local configurations are excluded via .gitignore and will not be pushed to GitHub.

---

## Tools Used

- yt-dlp: Audio and video downloader
- FFmpeg: Audio converter and ID3 metadata tagger
- Deno: JavaScript runtime supporting yt-dlp extraction

---

## Disclaimer

This project is intended for educational and personal use only. Users must comply with YouTube Terms of Service and applicable copyright laws.
