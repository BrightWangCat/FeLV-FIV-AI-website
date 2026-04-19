# scripts/

运维脚本。本目录入库,但备份产物本身落在 `/home/ubuntu/backups/lfa-reader/`,不入库。

## 数据备份

备份对象:`apps/backend/lfa_reader.db` 与 `apps/backend/uploads/`。

### 自动备份(systemd timer)

宿主机已安装三个 timer,自动在 `/home/ubuntu/backups/lfa-reader/<tier>/<UTC时间戳>/` 落快照:

| Tier | 触发 | 保留份数 |
|------|------|---------|
| hourly | 每小时整点 | 24 |
| daily  | 每天 02:00 UTC | 14 |
| weekly | 每周日 02:30 UTC | 8 |

查看下一次触发与上一次执行:

```
systemctl list-timers 'lfa-backup-*' --no-pager
journalctl -u 'lfa-backup@*' --since '24h ago' --no-pager
```

unit 文件位于 `/etc/systemd/system/lfa-backup@.service` 与
`/etc/systemd/system/lfa-backup-{hourly,daily,weekly}.timer`,均以 `ubuntu`
身份运行;不在仓库内,机器重做时需要重新装一次。

### 手工备份

在新需求前/重大改动前/迁移脚本生效前,主动 snapshot 一份:

```
scripts/backup.sh manual
```

手工快照不会被自动轮转,会一直留到手动清理。落在 `manual/` 子目录。

### 数据恢复

```
scripts/restore.sh <tier>/<timestamp>
# 例:
scripts/restore.sh hourly/20260419-014023
scripts/restore.sh manual/20260419-013934
```

执行流程:
1. 先把当前状态备份到 `pre-restore/`(自动保留 20 份,作为回滚网)
2. 停掉 `uvicorn`(避免文件占用)
3. 用 `cp` 替换 `lfa_reader.db`,如果快照里有 `uploads.tar.gz` 则解压覆盖 `uploads/`
4. 提示手动重启 uvicorn(脚本不自动启,以便先确认数据再上线)

直接运行 `scripts/restore.sh` 不带参数会列出所有可用快照。

## backup 与 restore 的注意事项

- 备份用 `sqlite3 .backup`(不是 `cp`)。这是 SQLite 的在线热备份命令,
  不阻塞 uvicorn 的并发读写,产物是事务一致的。
- `restore.sh` 必然停 uvicorn,所以会有几秒服务中断。
- `pre-restore/` 是恢复前的当前状态,如果恢复结果不对可立刻
  `restore.sh pre-restore/<最近时间戳>` 倒回去。
- 备份不包含 `.env`(secret)、`venv/`、代码本身。代码恢复走 `git`。
