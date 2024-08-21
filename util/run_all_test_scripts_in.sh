#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function run_all_test_scripts_in () {
  local TEST_BASEDIR="$1"; shift
  case "$TEST_BASEDIR" in
    --proj ) TEST_BASEDIR="$CI_PROJECT_DIR";;
    --repo ) TEST_BASEDIR="$(git rev-parse --show-toplevel)";;
  esac
  cd -- "$TEST_BASEDIR" || return 4$(
    echo E: $FUNCNAME: "Failed to chdir to test basedir: $TEST_BASEDIR" >&2)
  local TEST_SCRIPTS=()
  readarray -t TEST_SCRIPTS < <(sort --version-sort < <(
    git ls-files -- '**/'{test.'*','*'.test}.{pl,py,sed,sh} ) )

  local ITEM= SUBDIR= BFN= RV= PAD=
  printf -v PAD '% 150s' ''
  local SXS_CNT=0 ERR_CNT=0
  local FAILED=()
  for ITEM in "${TEST_SCRIPTS[@]}"; do
    <<<"P: >>>>> Test: $ITEM ${PAD// />}" cut -b 1-"${#PAD}"
    SUBDIR="$(dirname -- "$ITEM")"
    BFN="$(basename -- "$ITEM")"
    cd -- "$TEST_BASEDIR/$SUBDIR" && ./"$BFN"; RV=$?
    if [ "$RV" == 0 ]; then
      (( SXS_CNT += 1 ))
      ITEM="Test passed: $ITEM"
    else
      (( ERR_CNT += 1 ))
      FAILED+=( "$ITEM" )
      echo W: "Test failed: $ITEM" >&2
      ITEM="Test FAILED (rv=$RV): $ITEM"
    fi
    <<<"P: <<<<< $ITEM ${PAD// /<}" cut -b 1-"${#PAD}"
    echo
  done

  [ "$ERR_CNT" == 0 ] || return 4$(
    echo E: "Some tests (n=$ERR_CNT) failed! ($SXS_CNT passed.)" >&2)
  echo P: "Done. All tests passed. (n=$SXS_CNT)"
}










[ "$1" == --lib ] && return 0; run_all_test_scripts_in "$@"; exit $?
