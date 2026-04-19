#!/usr/bin/env bash
# LFA Reader 数据备份脚本
#
# 用法: backup.sh [tier]
#   tier 默认为 manual,可选: hourly | daily | weekly | manual | pre-restore
#
# 备份对象:
#   - apps/backend/lfa_reader.db   (sqlite3 .backup 在线热备,不阻塞 uvicorn)
#   - apps/backend/uploads/        (tar.gz 整目录)
#
# 输出位置:
#   /home/ubuntu/backups/lfa-reader/<tier>/<YYYYMMDD-HHMMSS>/
#     ├── lfa_reader.db
#     ├── uploads.tar.gz       (uploads 不存在时跳过)
#     └── metadata.json
#
# 轮转(同一 tier 下保留最近 N 份):
#   hourly=24, daily=14, weekly=8, manual=0(不删), pre-restore=20

set -euo pipefail

REPO_ROOT="/home/ubuntu/lfa-reader"
BACKUP_ROOT="/home/ubuntu/backups/lfa-reader"
DB_SRC="$REPO_ROOT/apps/backend/lfa_reader.db"
UPLOADS_SRC="$REPO_ROOT/apps/backend/uploads"

TIER="${1:-manual}"
case "$TIER" in
  hourly) RETAIN=24 ;;
  daily)  RETAIN=14 ;;
  weekly) RETAIN=8  ;;
  manual) RETAIN=0  ;;
  pre-restore) RETAIN=20 ;;
  *) echo "Unknown tier: $TIER" >&2; exit 2 ;;
esac

TS="$(date -u +%Y%m%d-%H%M%S)"
DEST="$BACKUP_ROOT/$TIER/$TS"
mkdir -p "$DEST"

log() { echo "[backup $TIER $TS] $*"; }

# 数据库备份:用 sqlite3 .backup 命令做在线热备
# 这条命令在 sqlite 内部以并发安全方式复制页面,不阻塞 uvicorn 的读写
if [ -f "$DB_SRC" ]; then
  sqlite3 "$DB_SRC" ".backup '$DEST/lfa_reader.db'"
  DB_SIZE=$(stat -c%s "$DEST/lfa_reader.db")
  log "db ok ($DB_SIZE bytes)"
else
  DB_SIZE=0
  log "db missing, skipped"
fi

# Uploads 备份:目录存在且非空才打包
if [ -d "$UPLOADS_SRC" ] && [ -n "$(ls -A "$UPLOADS_SRC" 2>/dev/null)" ]; then
  tar -czf "$DEST/uploads.tar.gz" -C "$REPO_ROOT/apps/backend" uploads
  UPLOADS_SIZE=$(stat -c%s "$DEST/uploads.tar.gz")
  UPLOADS_FILES=$(find "$UPLOADS_SRC" -type f | wc -l)
  log "uploads ok ($UPLOADS_SIZE bytes, $UPLOADS_FILES files)"
else
  UPLOADS_SIZE=0
  UPLOADS_FILES=0
  log "uploads empty/missing, skipped"
fi

# Metadata 便于人类与脚本快速判断每份快照
cat > "$DEST/metadata.json" <<EOF
{
  "tier": "$TIER",
  "timestamp_utc": "$TS",
  "db_bytes": $DB_SIZE,
  "uploads_bytes": $UPLOADS_SIZE,
  "uploads_files": $UPLOADS_FILES,
  "host": "$(hostname)"
}
EOF

# 轮转:RETAIN=0 表示不删
if [ "$RETAIN" -gt 0 ]; then
  TIER_DIR="$BACKUP_ROOT/$TIER"
  # 列出按名字倒序的子目录,跳过最新 RETAIN 个,删剩下的
  mapfile -t OLD < <(ls -1 "$TIER_DIR" | sort -r | tail -n +"$((RETAIN+1))")
  for old in "${OLD[@]}"; do
    rm -rf "${TIER_DIR:?}/$old"
    log "rotated out: $old"
  done
fi

log "done -> $DEST"
