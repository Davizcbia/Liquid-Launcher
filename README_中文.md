# Project Glass 11.12

本版修正账号原生控件的重复外框、快速下载版本列表、安装后卡片刷新，以及播放条图像同步。

## 运行

退出旧启动器，在解压目录执行：

```bash
bash build_macos.sh
```

脚本会编译并启动。默认使用已有 PrismLauncher 数据目录；缺失时使用 ProjectGlassCore 目录。请避免同时运行使用同一数据目录的其他启动器。PG_DATA_DIR 可指定独立数据目录。

缺少依赖时先执行：

```bash
brew install cmake ninja pkg-config extra-cmake-modules qt openjdk@17 cmark libarchive qrencode tomlplusplus zlib
```

## 本版

- 快速下载及嵌套下拉窗口各自保留原生玻璃附件，关闭下拉时不再切换其他窗口的材质状态。
- 快速下载的输入面板和下拉选中胶囊使用 NSGlassEffectView；选中胶囊按列表裁切。
- 下载版本列表每行提供原生玻璃 Download 按钮；点击行主体仅选中，点击按钮才开始安装。移除截图中的两行说明，非原版安装不再使用重复的底部 Install 按钮。
- 实例侧栏图标和播放条使用相同的卡片图案/自定义背景，默认图案搭配提取的颜色。
- 画布空白处右键“Edit card sizes…”进入尺寸编辑，拖动卡片边缘；“Done resizing”或 Esc 退出。最小 180×126，最大 640×480，宽高可独立调整并保存。三个预设仍保留。
- 自动布局/分组使用右边、下边和右下角调整，自动重新排列；自由布局支持四边及四角，保持对边位置。
- 保留 11.11 的完整正式版快速下载列表、安装后事件刷新，以及 Modrinth 安装接口。

## 验证范围

QML 解析、界面点击、100 项版本列表与重试、图像同步、75% 缩放下实际鼠标拖动和分组调整测试通过。另有 200 项边缘尺寸/固定对边检查及自定义尺寸布局测试通过。
当前环境未完成 macOS C++ 编译和原生界面实测。详细改动、测试和限制见 WORK_IN_PROGRESS.md。

Microsoft 登录仍需项目自身有效的客户端 ID；离线身份不需要 Microsoft 认证，缺失的游戏资源仍需要联网下载。

## 来源与许可

基于 Prism 官方提交 390a240abaefe389d1ab8510cc0ba5c2692a65be。
完整保留核心源码与许可证，新增核心接入代码采用 GPL-3.0-only；不是 Prism 官方发行版。
