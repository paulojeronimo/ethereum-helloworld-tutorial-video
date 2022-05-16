#!/usr/bin/env bash
set -eou pipefail
cd "$(dirname "$0")"

op=${1:-recreate}

remove() { find . -maxdepth 1 -type l -delete; }
recreate() { remove; find . -mindepth 2 -type f -exec ln -s '{}' \;; }

case "$op" in
  remove|recreate) $op;;
esac
