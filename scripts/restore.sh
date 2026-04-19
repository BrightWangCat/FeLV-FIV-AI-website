#!/usr/bin/env bash
# LFA Reader 数据恢复脚本
#
# 用法: restore.sh <snapshot-path | tier/timestamp>
#   restore.sh hourly/20260420-020000
#   restore.sh /home/ubuntu/backups/lfa-reader/manual/20260420-013000
#
# 行为:
#   1. 校验目标快照存在且包含 lfa_reader.db
#   2. 把当前状态自动备份到 pre-restore/<时间戳>(以防恢复出错可回滚)
#   3. 停掉正在跑的 uvicorn(避免文件被占用)
#   4. 替换 db,如有 uploads.tar.gz 则解压覆盖 uploads/
#   5. 提示用户手动重启后端
#
# 不自动重启 uvicorn,以便用户在还原后先确认数据再启动。

set -euo pipefail

REPO_ROOT="/home/ubuntu/lfa-reader"
BACKUP_ROOT="/home/ubuntu/backups/lfa-reader"
DB_DEST="$REPO_ROOT/apps/backend/lfa_reader.db"
UPLOADS_DEST="$REPO_ROOT/apps/backend/uploads"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <snapshot-path | tier/timestamp>" >&2
  echo "Available snapshots:" >&2
  for tier in hourly daily weekly manual pre-restore; do
    if [ -d "$BACKUP_ROOT/$tier" ]; then
      ls -1 "$BACKUP_ROOT/$tier" 2>/dev/null | sed "s|^|  $tier/|" >&2 || true
    fi
  done
  exit 2
fi

ARG="$1"
if [ -d "$ARG" ]; then
  SNAPSHOT="$ARG"
elif [ -d "$BACKUP_ROOT/$ARG" ]; then
  SNAPSHOT="$BACKUP_ROOT/$ARG"
else
  echo "Snapshot not found: $ARG" >&2
  exit 1
fi

if [ ! -f "$SNAPSHOT/lfa_reader.db" ]; then
  echo "Snapshot is missing lfa_reader.db: $SNAPSHOT" >&2
  exit 1
fi

echo "[restore] source: $SNAPSHOT"
[ -f "$SNAPSHOT/metadata.json" ] && cat "$SNAPSHOT/metadata.json"

# 1. 先把当前状态备份到 pre-restore/,作为安全网
echo "[restore] snapshotting current state to pre-restore/ ..."
"$REPO_ROOT/scripts/backup.sh" pre-restore

# 2. 停 uvicorn,防止数据库文件正被打开
if pgrep -f "venv/bin/uvicorn" > /dev/null; then
  echo "[restore] stopping uvicorn ..."
  pkill -f "venv/bin/uvicorn" || true
  sleep 1
fi

# 3. 替换 db
cp "$SNAPSHOT/lfa_reader.db" "$DB_DEST"
echo "[restore] db replaced ($(stat -c%s "$DB_DEST") bytes)"

# 4. 替换 uploads(若快照里有)
if [ -f "$SNAPSHOT/uploads.tar.gz" ]; then
  rm -rf "$UPLOADS_DEST"
  tar -xzf "$SNAPSHOT/uploads.tar.gz" -C "$REPO_ROOT/apps/backend"
  echo "[restore] uploads restored from tarball"
else
  echo "[restore] no uploads in snapshot, leaving uploads/ unchanged"
fi

echo "[restore] done. Restart uvicorn manually:"
echo "  cd $REPO_ROOT/apps/backend && nohup venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000 > uvicorn.log 2>&1 & disown"
