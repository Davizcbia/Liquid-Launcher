
<div align="center">
  <img
    width="256"
    height="256"
    alt="VL Logo"
    src="https://github.com/user-attachments/assets/47584ce2-d47e-41d6-af2a-237d2e904cc1"
  />
</div>


# Vitra Launcher

A Minecraft launcher with a Liquid Glass interface, built on [Prism Launcher](https://github.com/PrismLauncher/PrismLauncher). Designed on macOS 27; a Windows build is available too.

[简体中文](README_中文.md)

## Features

- Liquid Glass interface: sidebar, dock-style launch bar and an iPadOS Settings-style settings page
- Download Minecraft versions, Fabric, Forge, NeoForge and Quilt
- Download mods, resource packs, shaders and modpacks from Modrinth and CurseForge, with required dependencies listed first
- Instance canvas with groups, custom card sizes and backgrounds
- Microsoft sign-in and offline play
- Automatic updates (Windows), with a badge in Settings when a new version is out
- Optional memory optimization before the game starts (Windows)
- English and Simplified Chinese interface

## Download

### Windows

1. Download `VitraLauncher-Windows-MSVC-Portable-<version>.zip` from [Releases](https://github.com/Davizcbia/Vitra-Launcher/releases).
2. Unzip it to a folder of your choice.
3. Run `VitraLauncher.exe`.

This is a portable build: your instances, accounts and settings are stored in that folder. Version 1.1.0 and later update themselves; 1.0.0 has to be replaced by hand once.

### macOS

There is no packaged macOS release yet. Build it from source (below).

## Building from source

### Windows

Requirements: Visual Studio 2022 (C++ desktop workload), Qt 6.12 for MSVC 2022 64-bit (in `C:\Qt`), JDK 17 and vcpkg:

```bat
git clone https://github.com/microsoft/vcpkg core\cmake\vcpkg
build_windows.cmd
```

`build_windows.cmd` builds and starts the launcher; `build_windows.cmd --no-run` only builds it. To make the release zip:

```powershell
powershell -ExecutionPolicy Bypass -File package_windows.ps1
```

CurseForge needs an API key of your own: set `PG_CURSEFORGE_API_KEY` before building, or CurseForge is left out. Never commit the key.

### macOS

```bash
brew install cmake ninja pkg-config extra-cmake-modules qt openjdk@17 cmark libarchive qrencode tomlplusplus zlib
bash build_macos.sh
```

## Translations

Interface text lives in `translation/Vitra 界面翻译.xlsx`. After editing it, run `python translation/build_translations.py` (needs `openpyxl`) and rebuild.

## Known issues

- Not tested on macOS 26.
- The Windows build follows the macOS design; some materials look different from the native macOS version.

## License and credits

Vitra Launcher is a modified version of [Prism Launcher](https://github.com/PrismLauncher/PrismLauncher) (see [UPSTREAM.txt](UPSTREAM.txt)) and, like it, is licensed under the [GNU General Public License v3.0](LICENSE). It is not an official Prism Launcher release.

Vitra Launcher is not affiliated with or endorsed by Mojang, Microsoft, Modrinth or CurseForge. Minecraft is a trademark of Mojang AB.
