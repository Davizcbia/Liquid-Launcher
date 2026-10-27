# Microsoft sign-in

11.17 已内置用户提供的 Liquid Launcher 应用 Client ID，普通使用直接 Add Microsoft account。

如需开发者覆盖，可设置 PG_MSA_CLIENT_ID 后构建；已有运行时覆盖优先。Client ID 是应用标识，不是密码；无需 Client secret。

应用已注册不代表 Minecraft 服务端已批准访问。若失败，请保留真实错误，不要通过复制账号 token 绕过认证。当前版本未完成真实 Microsoft → Xbox → Minecraft 端到端验收。
