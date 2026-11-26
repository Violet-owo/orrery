#!/usr/bin/env bash
# Renders every page off-screen: tests/shots.sh OUTDIR  (needs cage and grim)
out=$1; here=$(dirname "$(readlink -f "$0")")/..; mkdir -p "$out"
for p in ${PAGES:-0 1 2 3 4 5 6 7 8 9}; do
  ORRERY_SCROLL=${SCROLL:-0} ORRERY_PAGE=$p WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 timeout 25 cage -- bash -c \
    "'$here/bin/orrery' >'$out/$p.log' 2>&1 & sleep ${WAIT:-5}; grim '$out/$p.png'; kill %1" >/dev/null 2>&1
  sed 's/\x1b\[[0-9;]*m//g' "$out/$p.log" | grep -E 'ERROR|WARN.*(scene|qml)' | sort | uniq -c | head -12
done
