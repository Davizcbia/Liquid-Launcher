# CurseForge 接入准备

1. 打开官方说明，点击 How to Apply for an API Key 下的申请表：
   https://support.curseforge.com/support/solutions/articles/9000208346-about-the-curseforge-api-and-how-to-apply-for-a-key
2. 如实填写启动器名称（以你最终采用的名称为准）、项目描述和网址、预期 API 用途、联系邮箱，并阅读第三方开发者条款。官方说明为 Overwolf 审核通过后邮件联系开发者。
3. 获得授权 Key 后，在本机使用 PG_CURSEFORGE_API_KEY 环境变量交给 build_macos.sh；构建脚本已提供 Launcher_CURSEFORGE_API_KEY 配置。不要把 Key 写入公开 GitHub 源码或截图。编译进客户端的 Key 也不能视为不可提取的秘密。
4. 当前 Project Glass 的下载目录和安装分发仍固定使用 Modrinth。后续需要实现 CurseForge 搜索、分类、版本/加载器筛选、文件与依赖解析，以及整合包的导入/安装分发，不能只配置 Key 或添加一个来源菜单。
5. 尊重作者对第三方分发的选择；对无法通过 API 下载的文件提供官网手动下载/导入路径。检查 API 及 CDN 请求认证，并处理 401/403、限流和无下载链接等情况。

官方 API 文档：https://docs.curseforge.com/rest-api/
官方 CDN 认证说明：https://blog.curseforge.com/introducing-api-key-authentication-for-curseforge-file-downloads/

本更新未启用 CurseForge 下载源，也未包含任何 CurseForge API Key。
