#!/usr/bin/env sh
# Add a weekly cron job (Sunday 00:00) that runs backup.sh. Idempotent.
set -eu
DIR=$(cd "$(dirname "$0")/.." && pwd)
JOB="0 0 * * 0 $DIR/scripts/backup.sh >> $DIR/backups/cron.log 2>&1"
( crontab -l 2>/dev/null | grep -v "backup.sh" ; echo "$JOB" ) | crontab -
crontab -l | grep backup.sh
