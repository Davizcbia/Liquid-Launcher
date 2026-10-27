Project Glass Prototype 09.31 — 原生 Liquid Glass 播放条
基准：09.30。

本版对应反馈：
1. 图标填充圆角底板，按比例居中裁剪，透明图标显示底色；图像和遮罩使用相同的圆角路径。
2. 图标尺寸=卡片高度-2×16，左/上/下均16pt，标题区垂直对齐。窄窗口下下载按钮下移避免覆盖描述。
3. Mods区右上角新增All loaders/Fabric/Forge/NeoForge/Quilt筛选，使用Modrinth服务端facet；筛选参与搜索、分页及重试。
4. 移除Load more按钮。列表延伸至窗口底边，在启动条后方滚动；接近列表末尾自动取下一页。使用稳定ListModel追加，避免每次加载返回顶部。末尾保留滚动留白，可将最后一张卡片完整移出启动条遮挡。
5. Sidebar、顶部导航和底部启动条共用glassOpacity、dockBlurAmount和全窗口对齐的背景采样；Settings新增Glass opacity（不降低文字透明度）。原Sidebar固定0.95模糊和固定底色已移除。设置内容可滚动。
6. 侧栏账户卡片和下载项目卡片使用macOS 27公开的NSView有效窗口圆角半径；低版本或未提供半径时使用20pt回退值。设置页卡片统一使用同一圆角值，其余控件维持09.30样式。
7. 底部启动条增加完整鼠标/双击/滚轮/滚动手势拦截。实例选择和Launch按钮仍可操作，启动条空白和文字区域不会点中下方卡片。
8. 玻璃下拉菜单沿用原有玻璃外观，改用ComboBox标准锚定定位；菜单与触发栏保留8pt间距，窗口下方空间不足时显示在触发栏上方。
9. 底部启动条改为与顶部导航相同的胶囊轮廓。
10. Download页移除大号Download标题和结果数量文本；保留搜索、类别、Refresh、loader和排序控件，并增加Modrinth/CurseForge选择。来源、搜索、Refresh、loader和排序控件统一为42pt高度和21pt圆角；Refresh/loader/排序组右边缘与搜索栏对齐。当前Modrinth目录可搜索；CurseForge会提示需要API key，API目录请求尚未接入。
11. macOS 26及以上版本将底部播放条替换为AppKit NSGlassEffectView原生Liquid Glass；实例标题、版本、位置，以及实例选择和Launch操作与QML同步。其他QML玻璃面板暂时沿用视觉近似，旧版macOS回退到QML播放条。

安装：
退出正在运行的ProjectGlassApp，将本包解压到Downloads后执行：
bash ~/Downloads/ProjectGlass_Prototype09_31/install_macos.sh
脚本会备份到项目backups/09.30-时间目录，复制本版7个必要文件，重新配置/编译并启动。
此版本不能只替换Main.qml；还需更新下载数据/逻辑、CMake和macOS入口文件及窗口指标头文件。

手工回退：
将脚本输出的Backup目录中的全部文件复制回
~/Developer/PrismLauncher/project-glass-ui
再运行cmake -S . -B build及cmake --build build --parallel 4。

验证：
QML加载；真实Fabric目录与项目版本打开；1220×780和850×560图标等距居中；共同透明度绑定；窗口圆角读值/回退和胶囊启动条；下拉菜单靠边定位；模拟鼠标确认拦截背景点击/双击且保留选择与Launch操作；滚轮和拖动不改变底下画布；本地HTTP服务验证加载器facet、自动分页、筛选复位及保留滚动位置。
当前环境不能运行macOS/AppKit，也不能完成Metal着色器渲染验证；macOS 27原生半径取值和图标GPU遮罩需在Mac实际运行核对。

功能边界不变：
macOS 26及以上版本的播放条现在使用AppKit NSGlassEffectView原生Liquid Glass，并将实例名称、版本、实例选择和Launch点击桥接回QML。其他QML玻璃面板仍是跨平台视觉近似，尚未逐个迁移到原生材质；低于macOS 26时播放条回退到QML样式。此轮未在macOS上编译或目视验证，需在macOS 26+运行确认材质显示、窗口缩放和交互。
真实在线目录已接入。下载安装、依赖解析、Prism真实实例读取尚未接入。
