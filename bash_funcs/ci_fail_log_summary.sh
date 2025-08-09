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

  tail --bytes=4K -- "$CI_LOG" |
    uniq | # The `uniq` is to tame node.js's `CallSite {},` spam.
    "$GHCIU_DIR"/util/common_logfile_optimizations/optim.sh |
    uniq | tail --lines=30 |
    ghciu_stepsumm_dump_textblock details '<open>Latest CI log messages'
    # ^-- implies ghciu_ensure_stepsumm_size_limit
}






[ "$1" == --lib ] && return 0; ci_fail_log_summary "$@"; exit $?
