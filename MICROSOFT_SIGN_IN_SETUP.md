# Microsoft sign-in

Vitra Launcher ships with its own registered Microsoft application (client ID `d7f05b47-6847-4be4-962c-e3548dd1b0d5`, set in `core/CMakeLists.txt` as `Launcher_MSA_CLIENT_ID`). Users sign in with **Add Microsoft account**; nothing needs to be configured.

## Using another client ID

If you build your own fork, register your own application in the Microsoft Entra admin center (personal Microsoft accounts and public client flows enabled) and build with it:

- macOS: `PG_MSA_CLIENT_ID=<your id> bash build_macos.sh`
- Windows: pass `-DLauncher_MSA_CLIENT_ID=<your id>` to CMake, or change the default in `core/CMakeLists.txt`

A client ID can also be set at runtime in **Settings › Launcher core › APIs**. It identifies the application and is not a secret; no client secret is used.

A registered application still needs Mojang's approval to use the Minecraft services API. If sign-in fails, keep the real error message; never work around authentication by copying account tokens.
