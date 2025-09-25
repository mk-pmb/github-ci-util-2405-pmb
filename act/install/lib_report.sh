#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function lib_report__panic () {
  echo '!! 🔥🌋🔥 !! PANIC !! 🔥🌋🔥 !! 🔥🌋🔥 !! 🔥🌋🔥 !! 🔥🌋🔥 !! 🔥🌋🔥 !!'
  echo "!! $*"
  echo '!! 🔥🌋🔥 !! PANIC !! 🔥🌋🔥 !! 🔥🌋🔥 !! 🔥🌋🔥 !! 🔥🌋🔥 !! 🔥🌋🔥 !!'
  echo '!!'
  env | grep -Pie 'github|container|runtime' \
    | LANG=C sort | sed -re 's!^([^=]+)=!\1:\n\1=!'
  exit 8
}










case "$1" in
  --lib ) return 0;;
  --debug ) shift; lib_report__"$@"; exit $?;;
esac
echo E: "Don't run $0 directly!" 'For the thing that reports your errors,' \
  'you need early warning if it becomes unavailable (e.g. due to rename)!' >&2
return 8 || exit 8
