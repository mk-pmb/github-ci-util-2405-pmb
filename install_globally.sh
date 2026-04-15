#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function install_globally () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local INIT_PWD="$PWD"
  local SELFPATH="$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")" # busybox
  local GLOBAL_BIN_PATH='/usr/local/bin'
  optimize_global_bin_path || return $?

  cd -- "$SELFPATH" || return $?
  <binlinks.cfg install_binlinks || return $?
  return 0

  cp -vT -- act/install/npmrc.basics.ini "$HOME"/.npmrc || return $?
  ensure_nodejs_symlink || return $?

  echo "===>>=== audit-ci: Check ghciu itself. ===>>==="
  IBM_AUDIT_CI_CFG= IBM_AUDIT_CI_FLAGS='no_success_badge' \
    "$SELFPATH"/util/ibm-audit-ci.sh || return $?
  echo "===<<=== audit-ci: Check ghciu itself. ===<<==="

  npm install --ignore-scripts=true . || return $?$(
    echo E: "Failed to npm install ghciu! rv=$?" >&2)

  [ . -ef "$INIT_PWD" ] && return 0
  cd -- "$INIT_PWD" || return $?$(
    echo E: 'Failed to chdir back to the workspace directory!' >&2)
  echo "==---== Default workspace checks and optimizations ==---=="

  echo "===>>=== audit-ci: Check the workspace directory. ===>>==="
  "$SELFPATH"/util/ibm-audit-ci.sh || return $?
  echo "===<<=== audit-ci: Check the workspace directory. ===<<==="
}


function optimize_global_bin_path () {
  local VAL=
  if [ -f /opt/etc/entware_release ]; then
    GLOBAL_BIN_PATH='/opt/local/bin'
    return 0
  fi
}


function ensure_nodejs_symlink () {
  local NJS="$(which nodejs 2>/dev/null | grep -Pe '^/')"
  [ -x "$NJS" ] && return 0
  local NODE="$(which node 2>/dev/null | grep -Pe '^/')"
  [ -x "$NODE" ] || return 4$(
    echo E: $FUNCNAME: "Cannot find an executable node.js!" >&2)
  NJS="$GLOBAL_BIN_PATH/nodejs"
  ln -vsT -- "$NODE" "$NJS" || return $?$(
    echo E: $FUNCNAME: "Cannot symlink node.js as nodejs!" >&2)
}


function install_binlinks () {
  local ORIG= LINK=
  while IFS= read -r ORIG; do
    case "$ORIG" in
      [a-z]*' <- '[a-z]* )
        LINK="${ORIG%%' <- '*}"
        ORIG="${ORIG#*' <- '}"
        ;;
      * ) continue;;
    esac
    LINK="$GLOBAL_BIN_PATH/$LINK"
    [ -L "$LINK" ] && rm -v -- "$LINK"
    ln -vsT -- "$SELFPATH/$ORIG" "$LINK" || return $?
  done
}


















install_globally "$@"; exit $?
