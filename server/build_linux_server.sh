#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BUNDLE_NAME="darwine-linux-server"
BUNDLE_DIR="$DIST_DIR/$BUNDLE_NAME"
ARTIFACT="$DIST_DIR/${BUNDLE_NAME}-ubuntu24-x86_64.tar.gz"
GODOT_VERSION="4.7-stable"
LINUX_BINARY_NAME="Godot_v${GODOT_VERSION}_linux.x86_64"
LINUX_ARCHIVE="$DIST_DIR/.cache/${LINUX_BINARY_NAME}.zip"
LINUX_DOWNLOAD_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${LINUX_BINARY_NAME}.zip"
EXPORT_LOG=""
TEMP_DIR=""

cleanup() {
	if [[ -n "$EXPORT_LOG" && -f "$EXPORT_LOG" ]]; then
		rm -f "$EXPORT_LOG"
	fi
	if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
		rm -rf "$TEMP_DIR"
	fi
}
trap cleanup EXIT

fail() {
	printf 'Hata: %s\n' "$1" >&2
	exit 1
}

find_godot() {
	if [[ -n "${GODOT_BIN:-}" ]]; then
		printf '%s' "$GODOT_BIN"
	elif [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
		printf '%s' "/Applications/Godot.app/Contents/MacOS/Godot"
	elif command -v godot4 >/dev/null 2>&1; then
		command -v godot4
	elif command -v godot >/dev/null 2>&1; then
		command -v godot
	else
		return 1
	fi
}

download_file() {
	local url="$1"
	local destination="$2"
	if command -v curl >/dev/null 2>&1; then
		curl -fL --retry 3 --progress-bar "$url" -o "$destination"
	elif command -v wget >/dev/null 2>&1; then
		wget -O "$destination" "$url"
	else
		fail "İndirme için curl veya wget gerekli."
	fi
}

GODOT_BIN_RESOLVED="$(find_godot)" || fail "Godot 4.7 bulunamadı. GODOT_BIN=/tam/yol ile belirtin."
command -v unzip >/dev/null 2>&1 || fail "unzip komutu gerekli."
command -v tar >/dev/null 2>&1 || fail "tar komutu gerekli."

mkdir -p "$DIST_DIR/.cache"
rm -rf "$BUNDLE_DIR"
rm -f "$ARTIFACT"
mkdir -p "$BUNDLE_DIR"

printf '1/4 Godot projesi dedicated PCK olarak paketleniyor...\n'
EXPORT_LOG="$(mktemp)"
if ! "$GODOT_BIN_RESOLVED" --headless --path "$ROOT_DIR" --export-pack "Linux Dedicated Server Pack" "$BUNDLE_DIR/darwine-server.pck" >"$EXPORT_LOG" 2>&1; then
	sed -n '1,260p' "$EXPORT_LOG" >&2
	fail "Godot PCK dışa aktarımı başarısız."
fi
if grep -E "SCRIPT ERROR|Parse Error|ERROR:" "$EXPORT_LOG" >/dev/null 2>&1; then
	grep -E -C 3 "SCRIPT ERROR|Parse Error|ERROR:" "$EXPORT_LOG" >&2 || true
	fail "Godot dışa aktarım günlüğünde hata bulundu."
fi
[[ -s "$BUNDLE_DIR/darwine-server.pck" ]] || fail "Dedicated PCK oluşturulmadı."

printf '2/4 Godot %s Linux x86_64 çalıştırıcısı hazırlanıyor...\n' "$GODOT_VERSION"
if [[ ! -f "$LINUX_ARCHIVE" ]] || ! unzip -tq "$LINUX_ARCHIVE" >/dev/null 2>&1; then
	rm -f "$LINUX_ARCHIVE"
	download_file "$LINUX_DOWNLOAD_URL" "$LINUX_ARCHIVE"
fi
unzip -tq "$LINUX_ARCHIVE" >/dev/null 2>&1 || fail "İndirilen Godot arşivi bozuk."
TEMP_DIR="$(mktemp -d)"
unzip -oq "$LINUX_ARCHIVE" -d "$TEMP_DIR"
[[ -f "$TEMP_DIR/$LINUX_BINARY_NAME" ]] || fail "Linux Godot çalıştırıcısı arşivde bulunamadı."
cp "$TEMP_DIR/$LINUX_BINARY_NAME" "$BUNDLE_DIR/godot"
chmod 0755 "$BUNDLE_DIR/godot"

printf '3/4 Tek komutluk çalıştırıcı ve belgeler ekleniyor...\n'
cp "$ROOT_DIR/server/darwine-server" "$BUNDLE_DIR/darwine-server"
cp "$ROOT_DIR/server/README_LINUX.md" "$BUNDLE_DIR/README.md"
cp "$ROOT_DIR/server/THIRD_PARTY_NOTICES.md" "$BUNDLE_DIR/THIRD_PARTY_NOTICES.md"
chmod 0755 "$BUNDLE_DIR/darwine-server"

printf '4/4 Ubuntu 24 dağıtım arşivi oluşturuluyor...\n'
# Prevent macOS extended attributes from becoming AppleDouble `._*` files
# when the archive is extracted on Linux.
COPYFILE_DISABLE=1 tar -C "$DIST_DIR" -czf "$ARTIFACT" "$BUNDLE_NAME"
[[ -s "$ARTIFACT" ]] || fail "Dağıtım arşivi oluşturulmadı."

ARTIFACT_SIZE="$(du -h "$ARTIFACT" | awk '{print $1}')"
printf 'Hazır: %s (%s)\n' "$ARTIFACT" "$ARTIFACT_SIZE"
