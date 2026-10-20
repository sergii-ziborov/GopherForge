#!/bin/sh
set -u
status=0
/usr/bin/python3 /srv/apps/gopherforge/news-feed/sync.py --directory /var/lib/gopherforge-news || status=$?
/usr/bin/python3 /srv/apps/gopherforge/news-feed/deliver.py /var/lib/gopherforge-news || exit 1
exit "$status"
