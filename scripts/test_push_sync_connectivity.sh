#!/usr/bin/env bash
set -euo pipefail

PACKAGE="${PACKAGE:-com.example.second_serving_frontend}"
BAD_BACKEND="${BAD_BACKEND:-http://10.255.255.1:9999}"
REAL_BACKEND="${REAL_BACKEND:-http://3.16.198.192}"
WAIT_AFTER_FCM_SECONDS="${WAIT_AFTER_FCM_SECONDS:-12}"
MAX_RUN_SECONDS="${MAX_RUN_SECONDS:-35}"

read_push_sync() {
  adb shell run-as "$PACKAGE" cat shared_prefs/FlutterSharedPreferences.xml \
    | grep 'pushSync' \
    | sed -E 's/(flutter\.pushSync\.token">).+/\1<redacted><\/string>/' || true
}

run_flutter_until_fcm_or_timeout() {
  local backend="$1"
  local log_file
  log_file="$(mktemp -t push-sync-flutter.XXXXXX.log)"

  echo "Flutter log: $log_file"
  flutter run --dart-define=API_BASE_URL="$backend" 2>&1 | tee "$log_file" &
  local flutter_pid=$!

  local elapsed=0
  local saw_token=0
  while kill -0 "$flutter_pid" 2>/dev/null; do
    if grep -q 'FCM_TOKEN' "$log_file"; then
      saw_token=1
      echo ""
      echo "FCM_TOKEN detected. Waiting ${WAIT_AFTER_FCM_SECONDS}s for the backend timeout to be persisted..."
      sleep "$WAIT_AFTER_FCM_SECONDS"
      break
    fi

    if [ "$elapsed" -ge "$MAX_RUN_SECONDS" ]; then
      echo ""
      echo "Max wait reached (${MAX_RUN_SECONDS}s). Stopping Flutter..."
      break
    fi

    sleep 1
    elapsed=$((elapsed + 1))
  done

  if kill -0 "$flutter_pid" 2>/dev/null; then
    kill "$flutter_pid" 2>/dev/null || true
    wait "$flutter_pid" 2>/dev/null || true
  fi

  if [ "$saw_token" -eq 0 ]; then
    echo "Warning: FCM_TOKEN was not detected before stopping."
  fi
}

echo ""
echo "STEP 1 - Run app with real backend and login normally"
echo "Command:"
echo "flutter run --dart-define=API_BASE_URL=$REAL_BACKEND"
echo ""
echo "After login, wait until you see FCM_TOKEN in logs."
echo "Then stop flutter run with q."
echo ""
read -r -p "Press ENTER when login is already done and the app was stopped..."

echo ""
echo "Current pushSync state:"
read_push_sync

echo ""
echo "STEP 2 - Run app with invalid backend to force notification sync failure"
echo "This should keep the saved session but make POST /notifications/device timeout."
echo ""
echo "Starting Flutter with bad backend..."
echo "The script will stop Flutter automatically after FCM_TOKEN is detected or after ${MAX_RUN_SECONDS}s."
echo ""

run_flutter_until_fcm_or_timeout "$BAD_BACKEND"

echo ""
echo "STEP 3 - Reading pushSync state after forced failure"
read_push_sync

echo ""
echo "Expected evidence:"
echo '  <string name="flutter.pushSync.status">pending</string>'
echo '  <string name="flutter.pushSync.pendingSince">...</string>'
echo '  <string name="flutter.pushSync.lastError">TimeoutException...</string>'

echo ""
echo "STEP 4 - Run app again with real backend to verify retry/sync"
echo "Command:"
echo "flutter run --dart-define=API_BASE_URL=$REAL_BACKEND"
echo ""
echo "After it starts, wait a few seconds and run:"
echo "adb shell run-as $PACKAGE cat shared_prefs/FlutterSharedPreferences.xml | grep pushSync"
echo ""
echo "Expected final evidence:"
echo '  <string name="flutter.pushSync.status">synced</string>'
