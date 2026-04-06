#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function install_ghciu () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local REPOPATH="$(readlink -m -- "$BASH_SOURCE"/../../..)"
  "$REPOPATH"/install_globally.sh || return $?
  ghciu ghciu+s://act/install/gather_ci_run_meta.sh || return $?
  ghciu_verify_nodejs_version || return $?
}


function ghciu_verify_nodejs_version () {
  local WANT="$WANT_NODEJS_VERSION"
  local HAVE="$(nodejs --version | grep -xPe 'v?\d[\d\.]+')"
  local MAJOR="${HAVE%%.*}"
  MAJOR="${MAJOR#v}"
  echo D: $FUNCNAME: "Found '$HAVE' => major = $MAJOR"
  local ERR=
  [ "${MAJOR:-0}" -ge 1 ] || ERR='Cannot determine the installed %NV!'
  [ -n "$ERR" ] || case "$WANT" in
    '' ) return 0;;
    *[^0-9]* ) ERR='%RNV contains a non-digit character!';;
    "$MAJOR" ) return 0;;
    [1-9]* ) ERR="%RNV is $WANT.* but we have $HAVE";;
    * ) ERR='%RNV must be a simple positive integer';;
  esac
  [ -n "$ERR" ] || ERR='Unexpected control flow!'
  ERR="${ERR//%RNV/Requested %NV}"
  ERR="${ERR//%NV/node.js version}"
  echo E: $FUNCNAME: "$ERR" >&2
  printf -- '\n### E: `%s:` %s\n\n' "$FUNCNAME" "$ERR" >>"$GITHUB_STEP_SUMMARY"
  return 4
}


install_ghciu "$@"; exit $?
