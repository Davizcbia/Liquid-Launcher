<p align="center"><img src="docs/vitra-icon.png" width="128" alt="Vitra Launcher 图标"></p>

# Vitra Launcher

一款采用液态玻璃界面的 Minecraft 启动器，基于 [Prism Launcher](https://github.com/PrismLauncher/PrismLauncher) 开发。在 macOS 27 上设计，同时提供 Windows 版本。

[English](README.md)

## 功能

- 液态玻璃界面：侧边栏、Dock 风格的启动栏，以及仿 iPadOS 设置的设置页
- 下载 Minecraft 各版本及 Fabric、Forge、NeoForge、Quilt
- 从 Modrinth 和 CurseForge 下载模组、资源包、光影包和整合包，并优先列出前置资源
- 实例画布：支持分组、自定义卡片大小和背景
- Microsoft 账户登录和离线游玩
- 自动更新（Windows），有新版本时设置上会显示小红点
- 可选：启动游戏前进行内存优化（Windows）
- 英文和简体中文界面

## 下载

### Windows

1. 在 [Releases](https://github.com/Davizcbia/Vitra-Launcher/releases) 下载 `VitraLauncher-Windows-MSVC-Portable-<版本号>.zip`。
2. 解压到任意文件夹。
3. 运行 `VitraLauncher.exe`。

这是便携版：实例、账户和设置都保存在这个文件夹里。1.1.0 及以后的版本会自动更新；1.0.0 需要手动换成新版本一次。

### macOS

目前还没有打包好的 macOS 版本，请按下面的方法从源代码编译。

## 从源代码编译

### Windows

需要：Visual Studio 2022（“使用 C++ 的桌面开发”）、Qt 6.12 MSVC 2022 64 位版（安装在 `C:\Qt`）、JDK 17，以及 vcpkg：

```bat
git clone https://github.com/microsoft/vcpkg core\cmake\vcpkg
build_windows.cmd
```

`build_windows.cmd` 会编译并启动启动器；加上 `--no-run` 则只编译。打包发布用的 zip：

```powershell
powershell -ExecutionPolicy Bypass -File package_windows.ps1
```

CurseForge 需要你自己的 API Key：编译前设置环境变量 `PG_CURSEFORGE_API_KEY`，否则不包含 CurseForge。不要把 Key 提交到仓库。

### macOS

```bash
brew install cmake ninja pkg-config extra-cmake-modules qt openjdk@17 cmark libarchive qrencode tomlplusplus zlib
bash build_macos.sh
```

## 翻译

界面文字在 `translation/Vitra 界面翻译.xlsx` 中。修改后运行 `python translation/build_translations.py`（需要 `openpyxl`），再重新编译。

## 已知问题

- 尚未在 macOS 26 上测试。
- Windows 版沿用 macOS 的设计，部分材质效果与 macOS 原生版本不同。

## 许可与致谢

Vitra Launcher 是 [Prism Launcher](https://github.com/PrismLauncher/PrismLauncher) 的修改版本（详见 [UPSTREAM.txt](UPSTREAM.txt)），与其相同，采用 [GNU 通用公共许可证 v3.0](LICENSE)。本项目不是 Prism Launcher 的官方发行版。

Vitra Launcher 与 Mojang、Microsoft、Modrinth、CurseForge 均无关联，也未获得其认可。Minecraft 是 Mojang AB 的商标。
