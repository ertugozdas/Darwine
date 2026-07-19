#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-$((43000 + RANDOM % 1000))}"
SECRET="${SECRET:-13579246}"
RULESET="${RULESET:-siege}"
TEMP_DIR="$(mktemp -d)"
SERVER_HOME="$TEMP_DIR/server-home"
CLIENT_ONE_HOME="$TEMP_DIR/client-one-home"
CLIENT_TWO_HOME="$TEMP_DIR/client-two-home"
SERVER_ONE_LOG="$TEMP_DIR/server-before-restart.log"
SERVER_TWO_LOG="$TEMP_DIR/server-after-restart.log"
CLIENT_ONE_LOG="$TEMP_DIR/client-one.log"
CLIENT_TWO_LOG="$TEMP_DIR/client-two.log"
PIDS=()

cleanup() {
	for pid in "${PIDS[@]:-}"; do
		if kill -0 "$pid" >/dev/null 2>&1; then
			kill "$pid" >/dev/null 2>&1 || true
			wait "$pid" >/dev/null 2>&1 || true
		fi
	done
	rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

fail_with_logs() {
	printf 'SERVER_RESTART_RECOVERY_SMOKE_FAILED: %s\n' "$1" >&2
	for log in "$SERVER_ONE_LOG" "$SERVER_TWO_LOG" "$CLIENT_ONE_LOG" "$CLIENT_TWO_LOG"; do
		if [[ -s "$log" ]]; then
			printf '\n[%s]\n' "$(basename "$log")" >&2
			sed -n '1,360p' "$log" >&2
		fi
	done
	exit 1
}

wait_for_marker() {
	local pid="$1"
	local log="$2"
	local marker="$3"
	local timeout_seconds="$4"
	local deadline=$((SECONDS + timeout_seconds))
	while (( SECONDS < deadline )); do
		if grep -q "$marker" "$log" 2>/dev/null; then
			return 0
		fi
		if ! kill -0 "$pid" >/dev/null 2>&1; then
			return 1
		fi
		sleep 0.1
	done
	return 1
}

mkdir -p "$SERVER_HOME" "$CLIENT_ONE_HOME" "$CLIENT_TWO_HOME"
GODOT_BIN_RESOLVED="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
[[ -x "$GODOT_BIN_RESOLVED" ]] || fail_with_logs "Godot bulunamadı."

HOME="$SERVER_HOME" "$GODOT_BIN_RESOLVED" --headless --path "$ROOT_DIR" -- \
	--server --smoke-server --smoke-server-restart --public-ip 127.0.0.1 \
	--port "$PORT" --secret "$SECRET" --ruleset "$RULESET" >"$SERVER_ONE_LOG" 2>&1 &
SERVER_ONE_PID=$!
PIDS+=("$SERVER_ONE_PID")
wait_for_marker "$SERVER_ONE_PID" "$SERVER_ONE_LOG" "DARWINE_INVITE_CODE=" 20 || fail_with_logs "İlk dedicated sunucu hazır olmadı."

INVITE_CODE="$(awk -F= '/^DARWINE_INVITE_CODE=/{code=$2} END{print code}' "$SERVER_ONE_LOG")"
[[ -n "$INVITE_CODE" ]] || fail_with_logs "Davet kodu okunamadı."

HOME="$CLIENT_ONE_HOME" "$GODOT_BIN_RESOLVED" --headless --path "$ROOT_DIR" -- \
	--smoke-client --smoke-server-restart --invite "$INVITE_CODE" --name "Restart One" \
	>"$CLIENT_ONE_LOG" 2>&1 &
CLIENT_ONE_PID=$!
PIDS+=("$CLIENT_ONE_PID")
HOME="$CLIENT_TWO_HOME" "$GODOT_BIN_RESOLVED" --headless --path "$ROOT_DIR" -- \
	--smoke-client --smoke-server-restart --invite "$INVITE_CODE" --name "Restart Two" \
	>"$CLIENT_TWO_LOG" 2>&1 &
CLIENT_TWO_PID=$!
PIDS+=("$CLIENT_TWO_PID")

wait_for_marker "$CLIENT_ONE_PID" "$CLIENT_ONE_LOG" "SERVER_RESTART_CLIENT_READY" 45 || fail_with_logs "Birinci istemci ilk maça giremedi."
wait_for_marker "$CLIENT_TWO_PID" "$CLIENT_TWO_LOG" "SERVER_RESTART_CLIENT_READY" 45 || fail_with_logs "İkinci istemci ilk maça giremedi."

# Abrupt termination intentionally exercises the last completed authoritative
# revision, not the normal lobby shutdown path.
kill -9 "$SERVER_ONE_PID" >/dev/null 2>&1 || true
wait "$SERVER_ONE_PID" >/dev/null 2>&1 || true
wait_for_marker "$CLIENT_ONE_PID" "$CLIENT_ONE_LOG" "SERVER_RESTART_CLIENT_RETRY" 30 || fail_with_logs "Birinci istemci yeniden bağlanma penceresine girmedi."
wait_for_marker "$CLIENT_TWO_PID" "$CLIENT_TWO_LOG" "SERVER_RESTART_CLIENT_RETRY" 30 || fail_with_logs "İkinci istemci yeniden bağlanma penceresine girmedi."

HOME="$SERVER_HOME" "$GODOT_BIN_RESOLVED" --headless --path "$ROOT_DIR" -- \
	--server --smoke-server --smoke-server-restart --public-ip 127.0.0.1 \
	--port "$PORT" --secret "$SECRET" --ruleset "$RULESET" >"$SERVER_TWO_LOG" 2>&1 &
SERVER_TWO_PID=$!
PIDS+=("$SERVER_TWO_PID")

wait_for_marker "$SERVER_TWO_PID" "$SERVER_TWO_LOG" "DARWINE_SERVER_MATCH_RESTORED" 25 || fail_with_logs "Sunucu aktif maçı diskten bulamadı."
wait_for_marker "$SERVER_TWO_PID" "$SERVER_TWO_LOG" "DARWINE_SERVER_SNAPSHOT_APPLIED" 25 || fail_with_logs "Sunucu snapshot'ı savaş alanına uygulayamadı."
wait_for_marker "$CLIENT_ONE_PID" "$CLIENT_ONE_LOG" "SERVER_RESTART_CLIENT_RECOVERED" 30 || fail_with_logs "Birinci istemci yeniden başlayan sunucudan tam snapshot alamadı."
wait_for_marker "$CLIENT_TWO_PID" "$CLIENT_TWO_LOG" "SERVER_RESTART_CLIENT_RECOVERED" 30 || fail_with_logs "İkinci istemci yeniden başlayan sunucudan tam snapshot alamadı."

if [[ "$RULESET" == "dominion" || "$RULESET" == "hakimiyet" || "$RULESET" == "1" ]]; then
	grep -q "DARWINE_SERVER_MATCH_RESTORED.*ruleset=Hakimiyet" "$SERVER_TWO_LOG" || fail_with_logs "Yeniden başlayan sunucu Hakimiyet ruleset'ini geri yüklemedi."
	grep -q "SERVER_RESTART_CLIENT_RECOVERED.*ruleset=Hakimiyet" "$CLIENT_ONE_LOG" || fail_with_logs "Birinci istemci geri yüklenen Hakimiyet maçını almadı."
	grep -q "SERVER_RESTART_CLIENT_RECOVERED.*ruleset=Hakimiyet" "$CLIENT_TWO_LOG" || fail_with_logs "İkinci istemci geri yüklenen Hakimiyet maçını almadı."
fi

for log in "$SERVER_ONE_LOG" "$SERVER_TWO_LOG" "$CLIENT_ONE_LOG" "$CLIENT_TWO_LOG"; do
	if grep -E "SCRIPT ERROR|Parse Error" "$log" >/dev/null 2>&1; then
		fail_with_logs "Godot günlüğünde betik hatası bulundu."
	fi
done

printf 'SERVER_RESTART_RECOVERY_SMOKE_OK match=restored clients=2 grace=90 ruleset=%s port=%s\n' "$RULESET" "$PORT"
