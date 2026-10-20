#!/bin/sh
# Operator-installed setup for the existing authorized GopherForge origin.
set -eu
install -d -m 0755 /srv/apps/gopherforge/news-feed /var/lib/gopherforge-news
for f in sync.py deliver.py run.sh; do
  if [ -f /srv/apps/gopherforge/news-feed/$f ]; then cp -p /srv/apps/gopherforge/news-feed/$f /srv/apps/gopherforge/news-feed/$f.previous; fi
  install -m 0644 "$f" /srv/apps/gopherforge/news-feed/$f
done
for f in gopherforge-news.service gopherforge-news.timer; do
  if [ -f /etc/systemd/system/$f ]; then cp -p /etc/systemd/system/$f /etc/systemd/system/$f.previous; fi
  install -m 0644 "$f" /etc/systemd/system/$f
done
install -d -m 0755 /etc/systemd/system/gopherforge-web.service.d
cat > /etc/systemd/system/gopherforge-web.service.d/news-cache.conf <<'UNIT'
[Service]
ExecStartPost=-/usr/bin/python3 /srv/apps/gopherforge/news-feed/deliver.py /var/lib/gopherforge-news
UNIT
systemd-analyze verify /etc/systemd/system/gopherforge-news.service /etc/systemd/system/gopherforge-news.timer
systemctl daemon-reload
systemctl enable --now gopherforge-news.timer
systemctl start gopherforge-news.service
