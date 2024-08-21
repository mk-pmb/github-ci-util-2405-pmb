#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function chdir_relative_and_source () {
  # args: <relative_path> <script_file> <script_args …>
  local CHDIR_REL="$1"; shift
  # ^-- must come first for shebang invocation with /usr/bin/env -S
  local INVOKED_AS="$1"; shift
  local INVOKED_IN="$PWD"
  local SELFFILE="$INVOKED_AS"
  case "$SELFFILE" in
    ci-proj://* ) SELFFILE="$CI_PROJECT_DIR${SELFFILE#*/}";;
    git-repo://* )
      SELFFILE="$(git rev-parse --show-toplevel)${SELFFILE#*/}";;
    ghciu://* ) SELFFILE="$GHCIU_DIR${SELFFILE#*/}";;
  esac
  SELFFILE="$(readlink -m -- "$SELFFILE")"
  [ -f "$SELFFILE" ] || return 4$(
    echo E: >&2 "$INVOKED_AS: Failed to resolve absolute path to self!")
  local SELFPATH="$(dirname -- "$SELFFILE")"
  cd -- "$SELFPATH" || return 4$(
    echo >&2 E: "$INVOKED_AS: Failed to chdir to $SELFPATH")
  local CHDIR_FX= CHDIR_FY=.

  case "$CHDIR_REL" in
    '' | . | /* | ./* | ../* ) ;;

    --*:* )
      CHDIR_REL="${CHDIR_REL#--}"
      CHDIR_FX="${CHDIR_REL%%:*}"
      CHDIR_REL="${CHDIR_REL#*:}"
      ;;

    --* ) CHDIR_FX="${CHDIR_REL#--}"; CHDIR_REL=.;;
  esac

  case "$CHDIR_FX" in
    '' ) ;;
    ci-proj ) CHDIR_FY="$CI_PROJECT_DIR";;
    git-repo ) CHDIR_FY="$(git rev-parse --show-toplevel)";;

    test-verify-expected-output | \
    '' ) chdir_relative_and_source__"${CHDIR_FX//-/_}" "$@"; return $?;;

    * )
      echo E: >&2 "$INVOKED_AS: Unsupported chdir magic option: '$CHDIR_FX'"
      return 4;;
  esac

  [ -n "$CHDIR_FY" ] || return 4$(
    echo E: >&2 "$INVOKED_AS: The chdir magic option '$CHDIR_FX'" \
      "failed to determine a path.")
  [ "$CHDIR_FY" == . ] || cd -- "$CHDIR_FY" || return 4$(
    echo E: >&2 "$INVOKED_AS: Failed to chdir from '$PWD' to '$CHDIR_FY'" \
      " as determined by chdir magic option '$CHDIR_FX'.")
  cd -- "$CHDIR_REL" || return 4$(
    echo E: "$INVOKED_AS: Failed to chdir from $PWD to $CHDIR_REL" >&2)
  in_func eval 'source -- "$SELFFILE" "$@"' "$@"; return $?
}


function chdir_relative_and_source__test_verify_expected_output () {
  local BFN="$(basename -- "$SELFFILE")"
  BFN="${BFN%.sh}"
  BFN="${BFN%.test}"
  local EO=
  for EO in "$BFN".expected{,-output}.txt; do [ -f "$EO" ] && break; done
  local AO="tmp.$BFN.log"
  in_func source -- "$SELFFILE" "$@" &>"$AO" || return $?$(
    echo E: "Test '$SELFFILE' returned error code $?" >&2)
  local MAXLN="$(stat -c %s -- "$EO")0"
  (( MAXLN += 9009009 ))
  local DIFF_REPORT="tmp.$BFN.diff"
  diff --report-identical-files --suppress-blank-empty --unified="$MAXLN" \
    -- "$EO" "$AO" >"$DIFF_REPORT"
  local DIFF_RV=$?
  if [ "$DIFF_RV" == 0 ]; then
    cat -- "$DIFF_REPORT"
    rm -- "$DIFF_REPORT"
    return 0
  fi
  colordiff <"$DIFF_REPORT"
  echo D: "diff report is in: $DIFF_REPORT"
  return "$DIFF_RV"
}














[ "$1" == --lib ] && return 0; chdir_relative_and_source "$@"; exit $?
