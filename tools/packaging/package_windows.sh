#!/usr/bin/env bash
# 打 Windows 试玩包(2026-10-14):导出正式版(release,不开试玩记录)→ 附说明 → zip。
#
#     bash tools/packaging/package_windows.sh
#
# 输出 build/TheCradle-windows-<日期>-<提交>.zip,里面一个 TheCradle/ 文件夹:
#   TheCradle.exe(游戏数据嵌在 exe 里,单文件)+ README.txt(怎么开、操作、回馈,繁体)。
# 导出设定在 export_presets.cfg「Windows Desktop」(排除 production / design / docs / tools)。
# 需要 Godot 4.6.2 的 Windows 导出模板:~/Library/Application Support/Godot/export_templates/4.6.2.stable/
# (编辑器「管理导出模板」装,或只装 windows_release_x86_64.exe + version.txt)。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-/Users/shihtsun/Library/Mobile Documents/com~apple~CloudDocs/2-创作/03-Godot工程/Godot.app/Contents/MacOS/Godot}"
VERSION="$(git -C "$ROOT" rev-parse --short HEAD)"
[ -n "$(git -C "$ROOT" status --porcelain)" ] && VERSION="${VERSION}+改"
DATE="$(date +%Y-%m-%d)"
STAGE="$ROOT/build/TheCradle"
ZIP="$ROOT/build/TheCradle-windows-$(date +%Y%m%d)-${VERSION%+改}.zip"

rm -rf "$STAGE" "$ROOT/build/windows"
mkdir -p "$STAGE"
"$GODOT" --headless --path "$ROOT" --export-release "Windows Desktop" "$STAGE/TheCradle.exe" 2>&1 \
    | grep -iE "error|warn" || true
[ -s "$STAGE/TheCradle.exe" ] || { echo "导出失败:没有 TheCradle.exe" >&2; exit 1; }

# 说明:UTF-8 带 BOM + CRLF,Windows 记事本打开不乱码
{
    printf '\xEF\xBB\xBF'
    sed -e "s/{VERSION}/$VERSION/" -e "s/{DATE}/$DATE/" "$ROOT/tools/packaging/windows-readme.txt" | sed 's/$/\r/'
} > "$STAGE/README.txt"

rm -f "$ZIP"
(cd "$ROOT/build" && zip -qr -X "$ZIP" TheCradle)
echo "→ ${ZIP#$ROOT/}($(du -h "$ZIP" | cut -f1),版本 $VERSION)"
