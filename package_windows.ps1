# Builds Vitra Launcher and packs the portable zip that the updater installs.
#   powershell -ExecutionPolicy Bypass -File package_windows.ps1 [-NoBuild]
# Output: dist\VitraLauncher-Windows-MSVC-Portable-<version>.zip
# Attach it to a GitHub release of Davizcbia/Vitra-Launcher whose tag is the
# version number alone (for example 1.0.1); the version comes from
# core\CMakeLists.txt (Launcher_VERSION_MAJOR/MINOR/PATCH).
param([switch]$NoBuild)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

$cmake = Get-Content "$root\core\CMakeLists.txt" -Raw
$version = ('MAJOR', 'MINOR', 'PATCH' | ForEach-Object { [regex]::Match($cmake, "set\(Launcher_VERSION_$_ (\d+)\)").Groups[1].Value }) -join '.'

# The same defaults as build_windows.cmd: the updater is only built when both are set.
if (-not $env:PG_UPDATER_REPO) { $env:PG_UPDATER_REPO = 'https://github.com/Davizcbia/Vitra-Launcher' }
if (-not $env:PG_BUILD_ARTIFACT) { $env:PG_BUILD_ARTIFACT = 'Windows-MSVC' }
if (-not $NoBuild) {
    cmd /c "`"$root\build_windows.cmd`" --no-run"
    if ($LASTEXITCODE) { throw 'Build failed.' }
}
$release = "$root\core\build-win11\Release"
$config = Get-Content "$root\core\build-win11\buildconfig\BuildConfig.cpp" -Raw
if ($config -notmatch [regex]::Escape($env:PG_UPDATER_REPO) -or -not (Test-Path "$release\VitraLauncher_updater.exe")) {
    throw 'This build has no updater. Build again without -NoBuild.'
}

$name = "VitraLauncher-Windows-MSVC-Portable-$version"
$stage = "$root\dist\$name"
Remove-Item $stage, "$stage.zip" -Recurse -Force -ErrorAction SilentlyContinue
New-Item $stage -ItemType Directory | Out-Null
# Program files only: the build folder holds no user data (that is in
# %APPDATA%), but leave out the redistributable installer, the QML debugger
# plugins, debug symbols and executables left from the old "prismlauncher" name.
Get-ChildItem $release | Where-Object { $_.Name -notin 'vc_redist.x64.exe', 'qmltooling' -and $_.Extension -ne '.pdb' -and $_.Name -notlike 'prismlauncher*' } |
    Copy-Item -Destination $stage -Recurse

# The VC++ runtime next to the executable (app-local deployment), so the zip
# runs on PCs without the Visual C++ Redistributable.
$crt = Get-ChildItem 'C:\Program Files\Microsoft Visual Studio\2022\*\VC\Redist\MSVC\*\x64\Microsoft.VC143.CRT' -Directory |
    Sort-Object FullName -Descending | Select-Object -First 1
if (-not $crt) { throw 'Visual C++ runtime (Microsoft.VC143.CRT) not found in the Visual Studio redist folder.' }
Copy-Item "$($crt.FullName)\*.dll" $stage

# portable.txt: data (instances, accounts, settings) stays beside the program,
# and the updater takes the portable zip path.
New-Item "$stage\portable.txt" -ItemType File | Out-Null
# manifest.txt: every packaged file. An update backs up and replaces exactly
# these, so instances and other data in the folder are kept.
$files = Get-ChildItem $stage -Recurse -File | ForEach-Object { $_.FullName.Substring($stage.Length + 1).Replace('\', '/') }
[IO.File]::WriteAllText("$stage\manifest.txt", (($files + 'manifest.txt') -join "`n"), (New-Object Text.UTF8Encoding($false)))

# Files at the zip root (the updater runs VitraLauncher_updater.exe from there).
# Entries are added one by one with "/" separators: ZipFile.CreateFromDirectory
# under Windows PowerShell writes "\", which extractors take as part of a name.
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::Open("$stage.zip", [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($entry in $files + 'manifest.txt') {
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, "$stage\$($entry.Replace('/', '\'))", $entry, [IO.Compression.CompressionLevel]::Optimal)
    }
} finally { $zip.Dispose() }
$size = [math]::Round((Get-Item "$stage.zip").Length / 1MB, 1)
Write-Host "Packed $name.zip ($size MB, $($files.Count + 1) files)"
Write-Host "Release: tag $version on https://github.com/Davizcbia/Vitra-Launcher/releases/new, attach dist\$name.zip"
