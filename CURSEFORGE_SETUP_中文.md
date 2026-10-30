# CurseForge 设置

Vitra Launcher 的下载页同时支持 Modrinth 和 CurseForge。CurseForge 的接口需要 API Key，这个 Key **不在源代码里**，由编译时的环境变量提供。

## 自己编译时

1. 按 CurseForge 官方说明申请 Key：
   https://support.curseforge.com/support/solutions/articles/9000208346-about-the-curseforge-api-and-how-to-apply-for-a-key
2. 编译前设置环境变量 `PG_CURSEFORGE_API_KEY`（PowerShell 中请用单引号，Key 里的 `$` 不能被当成变量）：

   ```powershell
   [Environment]::SetEnvironmentVariable('PG_CURSEFORGE_API_KEY', '你的Key', 'User')
   ```

   Windows 的 `build_windows.cmd` 和 macOS 的 `build_macos.sh` 都会读取它。没有设置时，编译出来的启动器不包含 CurseForge。
3. 也可以在启动器的 **设置 › 启动器内核 › APIs** 里填写自己的 Key。

## 注意

- 不要把 Key 写进源代码、提交到仓库或出现在截图里。编译进程序的 Key 也可能被提取，不能当作绝对保密的东西。
- 尊重作者对第三方分发的选择：作者禁止第三方下载的文件，启动器会打开它在 CurseForge 官网的页面，由用户手动下载。

官方 API 文档：https://docs.curseforge.com/rest-api/
