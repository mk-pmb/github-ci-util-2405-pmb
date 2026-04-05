#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function ci_fail_log_summary () {
  [ -n "$GITHUB_STEP_SUMMARY" ] || local GITHUB_STEP_SUMMARY='/dev/stdout'

  FMT=h2 fmt_markdown_textblock stepsumm deco --volcano "$FAIL_REPORT"
  if [ ! -s "$CI_LOG" ]; then
    echo "ghciu: Empty CI log albeit task failed (rv=$RV): \`$CI_LOG\`" \
      >>"$GITHUB_STEP_SUMMARY"
    return 0
  fi

  local SUMM_TMP="${CFG[logsdir]}/tmp.$FUNCNAME.$$"
  tail --bytes=4K -- "$CI_LOG" | uniq >"$SUMM_TMP".tail-raw.txt
    # ^-- The `uniq` is to tame node.js's `CallSite {},` spam.

  local NPM_LOG="$(grep -Fe 'A complete log of this run can be found in: ' \
    -- "$SUMM_TMP".tail-raw.txt | sed -nre 's~^.*:\s+~~p' | tail --lines=1)"
  [ ! -f "$NPM_LOG" ] || ci_fail_log_summary__npm >>"$SUMM_TMP".tail-raw.txt

  <"$SUMM_TMP".tail-raw.txt \
  "$GHCIU_DIR"/util/common_logfile_optimizations/optim.sh |
    uniq | tail --lines=30 >"$SUMM_TMP".tail-optim.txt
  ghciu_stepsumm_dump_file "$SUMM_TMP".tail-optim.txt \
    --title 'Latest CI log messages' --open
    # ^-- implies ghciu_ensure_stepsumm_size_limit
  rm -- "$SUMM_TMP".*
}


function ci_fail_log_summary__npm () {
  echo "From npm log ${NPM_LOG##*/}:"
  tail --bytes=4M -- "$NPM_LOG" | sed -rf <(echo '
    1d
    s~^[ \t0-9]*~~
    /^(http|silly|verbose) /d
    /^error notarget [^@]+$/d
    /^error A complete log of this run can be found in: /d
    ') | sed -rf <(echo '
    /info using /{
      : merge_using
        N; s~\ninfo using ~, ~
      t merge_using
    }
    ') | uniq | tail --lines=100 >"$SUMM_TMP".npm-raw.txt

  ci_fail_log_summary__npm_misspkg

  local OUT_DIR="$GITHUB_WORKSPACE/.npm-logs"
  mkdir --parents -- "$OUT_DIR"
  mv --no-clobber --verbose --target-directory="$OUT_DIR" -- "$NPM_LOG"
}


function ci_fail_log_summary__npm_misspkg () {
  local LIST=()
  readarray -t LIST < <(
    grep -Pe '^error notarget ' -- "$SUMM_TMP".npm-raw.txt |
    grep -oPe ' for \S+@\S+$' | sed -re 's~\.$~~; s~^.* for ~~')
  [ -n "${LIST[0]}" ] || return 0
  echo "Unsolved packages (n=${#LIST[@]}): ${LIST[*]}"

  local DEPS_LIST="$SUMM_TMP".npm-alldeps.txt
  sed -nrf <(echo '
    s~^[0-9 ]+silly placeDep ($1=solicitor_dir|\S+|$\
      ) ($2=wants_pkgname|\S+) OK for: ($3=solicitor_pkg|\S+|$\
      ) want: ($4=wants_version|\S+|$\
      )$~<pkg \3 ><at \1 ><wants \2 ><ver \4 >~
    /^<pkg /!b
    s~@([^@ ]*)( ><ver \S+ >)$~\2<gets \1 >~
    s~<gets  >$~<UNAVAIL>~
    p
    ') -- "$NPM_LOG" >"$DEPS_LIST"

  local PKG= VER=
  for PKG in "${LIST[@]}"; do
    VER="${PKG##*@}"
    PKG="${PKG%@*}"
    grep -Fe "<wants $PKG" -- "$DEPS_LIST"
  done | sed -re 's~[<> ]+~ ~g; s~^~Deps:~; s~ $~~'
}






[ "$1" == --lib ] && return 0; ci_fail_log_summary "$@"; exit $?
