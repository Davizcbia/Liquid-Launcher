#!/bin/bash
set -euo pipefail
package_dir="$(cd "$(dirname "$0")" && pwd)"
if [ "$(uname -s)" != Darwin ]; then echo "This build script targets macOS.";exit 1;fi
for tool in cmake ninja brew; do
    if ! command -v "$tool" >/dev/null; then echo "Missing $tool. See README_中文.md for dependencies.";exit 1;fi
done
qt_prefix="$(brew --prefix qt)"
brew_prefix="$(brew --prefix)"
if [ -z "${JAVA_HOME:-}" ]; then export JAVA_HOME="$(/usr/libexec/java_home -v 17)";fi
dependency_prefixes="$qt_prefix;$brew_prefix"
for dependency in cmark libarchive qrencode tomlplusplus zlib; do
    dependency_prefix="$(brew --prefix "$dependency")"
    dependency_prefixes="$dependency_prefixes;$dependency_prefix"
    export PKG_CONFIG_PATH="$dependency_prefix/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
done
build_dir="$package_dir/build"
cmake -S "$package_dir/core" -B "$build_dir" -G Ninja \
    -DCMAKE_SUPPRESS_REGENERATION=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$dependency_prefixes" \
    -DLauncher_USE_PCH=OFF -DBUILD_TESTING=OFF \
    -DLauncher_MSA_CLIENT_ID="${PG_MSA_CLIENT_ID:-d7f05b47-6847-4be4-962c-e3548dd1b0d5}" \
    -DLauncher_CURSEFORGE_API_KEY="${PG_CURSEFORGE_API_KEY:-}" \
    -DLauncher_IMGUR_CLIENT_ID=""
cmake --build "$build_dir" --target PrismLauncher JavaCheck NewLaunch NewLaunchLegacy --parallel "${PG_BUILD_JOBS:-4}"
# Bundle Java helpers before launching directly from the build tree.
jar_dir="$build_dir/PrismLauncher.app/Contents/MacOS/jars"
mkdir -p "$jar_dir"
for helper in JavaCheck NewLaunch NewLaunchLegacy; do
    source_jar="$build_dir/jars/$helper.jar"
    test -s "$source_jar" || { echo "Missing Java helper: $source_jar" >&2; exit 1; }
    cp "$source_jar" "$jar_dir/$helper.jar"
done
game_data_dir="${PG_DATA_DIR:-$HOME/Library/Application Support/PrismLauncher}"
if [ ! -d "$game_data_dir" ]; then game_data_dir="$HOME/Library/Application Support/ProjectGlassCore";fi
printf 'Project Glass built-in core data: %s\n' "$game_data_dir"
exec "$build_dir/PrismLauncher.app/Contents/MacOS/prismlauncher" --dir "$game_data_dir"
