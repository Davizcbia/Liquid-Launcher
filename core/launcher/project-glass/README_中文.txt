Project Glass 10.16 · Prism 实际启动接入（第一阶段）

先在 Prism Launcher 登录正版账号、创建实例，并确认它本身能启动游戏。
解压本包，然后运行：
bash ~/Downloads/ProjectGlass_Prototype10_16/install_macos.sh
安装会把当前源码备份到 project-glass-ui-backups/10.00-时间戳。

自动检测：
/Applications/Prism Launcher.app
~/Library/Application Support/PrismLauncher

在 Settings → Prism connection…，或 Launch 空白右键 → Prism connection…，选择 Prism 应用和数据根目录，点 Connect / Refresh。根目录应包含 prismlauncher.cfg，不是 instances 目录。
真实实例会加入画布和侧边栏；发现真实实例后，已安装的测试卡片会自动隐藏。选择真实实例后点击播放条 Launch，或双击卡片，交给 Prism 的 --dir / --launch 命令启动。测试卡片不会执行游戏启动。

这是调用已安装 Prism 的桥接版，尚未嵌入 Prism 核心。Prism 窗口可能出现；账号、Java、Mod 安装、内存和游戏日志仍在 Prism 管理。此阶段不读账号文件，不改实例配置或存档。Project Glass 的内存滑块尚不控制真实游戏。现有复制/删除/编辑仍是界面原型，不能视为真实实例文件管理。

连接状态和命令启动失败会显示在界面；Launch logs 打开本地桥接日志目录。若已有 Prism 进程接收命令，详细游戏错误请在 Prism 实例控制台查看。发送成功不代表 Minecraft 已进入游戏，进程状态、退出码和游戏日志回传将在下一阶段接入。

已检查 QML 语法和页面状态。当前环境没有 macOS，未实际启动 Minecraft，需在本机验证。

10.10 Free 模式：先关闭 Group，再在画布空白右键打开 Free mode。拖卡片移动；选中后拖右下角调整大小。卡片右键 Card size 或 Show on canvas 设置大小/可见性。隐藏后在空白右键 Visible cards 中恢复。位置、大小、隐藏状态自动保存；开启 Group 暂停 Free 布局。Free 下用滚轮平移画布。

10.10 新增：卡片右键 Layer 可置顶、置底或逐层移动；画布右键 Prevent overlap 开启防重叠，Minimum gap 选择 8–64pt 最小间距。Free 模式支持滚轮平移和空白处拖动画布。macOS 卡片的玻璃、文字、图标和图片统一在同一个原生容器内更新和排序。
验证：192 项布局断言、QML 语法和安装脚本语法通过；未完成 macOS 原生编译与实机显示验证。

10.11：修正侧边栏合成图的坐标方向、原始位置和尺寸，固定捕获时的卡片坐标。卡片右键 Show on canvas 和画布右键 Visible cards 现支持普通、Group、Free 三种画布；隐藏不删除实例，侧边栏仍保留入口。QML/脚本语法和192项布局检查通过，macOS显示效果待实机确认。

10.12：Free 卡片右下角蓝块改成悬停才出现的细线缩放提示。Launch 页改为真实原生卡片直接从侧边栏玻璃下经过，不再使用单独合成的卡片图和人工光晕。保留其他页的采样。QML、脚本和192项布局检查通过；Mac 原生编译及侧边栏实际采样尚未验证。

10.13：接入 Apple 官方 NSBackgroundExtensionView。由系统将画布边缘内容镜像、模糊延伸到侧边栏下方；不使用手算色带。侧边栏展开宽度、窗口尺寸及壁纸变化会更新延伸内容，卡片继续沿用窗口坐标和原交互。API不可用时保留原生卡片路径。QML、安装脚本和192项布局断言通过；尚未完成Mac原生编译，实际光晕强度、缩放及滚动效果需实机确认。

10.14：Settings滚动视口扩到页面两侧，保持原卡片宽度与全局位置；滚动容器透明、无边框。侧边栏延伸源改成壁纸和封面的大块低频颜色，排除文字、图标、按钮与清晰卡片轮廓；原生延伸输出仅显示于侧边栏。真实卡片位置不变。这是针对所需观感的实现，不声称复刻Apple Music内部代码。QML、安装脚本和192项布局检查通过；Mac原生编译与视觉效果尚未验证。

10.15：撤掉镜像延伸实现，改成取封面平均颜色的柔和光晕。光晕中心跟随卡片实际高度，上下和横向平滑衰减，远离侧栏时减弱，总透明度设上限；不复制卡片、图片和文字。卡片主体在侧栏边缘裁切。保留10.14的Settings修改。这是自定义光晕，不是Apple Music内部实现。QML、脚本、192项布局检查及光晕位置/衰减检查通过；Mac原生编译与视觉效果尚未验证。

10.16：去掉侧栏边界对卡片的硬裁切，完整卡片在sidebar玻璃下方经过。保留窗口/滚动区域裁切、现有光晕和卡片位置。QML、安装脚本与192项布局检查通过；Mac原生编译及实际显示尚未验证。
