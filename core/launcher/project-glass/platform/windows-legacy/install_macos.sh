#!/bin/bash
set -eu
package_dir="$(cd "$(dirname "$0")" && pwd)"
project_dir="${HOME}/Developer/PrismLauncher/project-glass-ui"
if [ ! -f "$project_dir/Main.qml" ] || [ ! -f "$project_dir/CMakeLists.txt" ]; then
    echo "Project folder not found: $project_dir"
    exit 1
fi
backup_dir="$project_dir/backups/09.30-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"
for name in Main.qml DownloadData.qml DownloadLogic.js CMakeLists.txt main.cpp MacWindow.mm MacWindowMetrics.h; do
    if [ -f "$project_dir/$name" ]; then cp "$project_dir/$name" "$backup_dir/$name"; fi
    cp "$package_dir/$name" "$project_dir/$name"
done
printf 'Backup: %s\n' "$backup_dir"
cd "$project_dir"
cmake -S . -B build
cmake --build build --parallel 4
exec ./build/ProjectGlassApp
