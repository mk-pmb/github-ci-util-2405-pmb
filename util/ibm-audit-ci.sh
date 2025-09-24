#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function ibm_audit_ci_cli_init () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFPATH="$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")" # busybox
  local KEY= VAL=

  [ -n "$CI" ] || return 0$(
    echo W: "Skipping audit-ci because env var CI is empty!" >&2)

  local AC_MINVER=7
  local AC_VER="$GHCIU_AUDIT_CI_VER"
  [ "${AC_VER:-0}" -ge "$AC_MINVER" ] || AC_VER="$AC_MINVER"

  local AC_CFG="$IBM_AUDIT_CI_CFG"
  [ -n "$AC_CFG" ] || AC_CFG="$(
    grep -HFe '"$schema":' -- *audit-ci*.*son* 2>/dev/null |
      grep -Fe '"https://github.com/IBM/audit-ci/raw/main/docs/schema.json"' |
      tr '$:' '\t' | cut -sf 1)"
  [ -f "$AC_CFG" ] || AC_CFG="$SELFPATH/ibm-audit-ci.ceson"

  local PKG_MGR='npm'
  # … except if we find files that audit-ci can use to auto-detect PKG_MGR:
  VAL='
    bun.lockb
    pnpm-lock.yaml
    yarn.lock
    '
  for VAL in $VAL; do
    [ -f "$VAL" ] || continue
    PKG_MGR=auto
    break
  done

  local AC_OPT=(
    --config "$REPO_AUDIT_CI_CFG"
    --package-manager "$PKG_MGR"
    )

  echo D: "Running IBM audit-ci in '$PWD' with config '$AC_CFG'."
  npx 'audit-ci@^'"$AC_VER" "${AC_OPT[@]}" ||
    return $?$(echo E: "IBM audit-ci failed in '$PWD'! rv=$?" >&2)
  echo D: "IBM audit-ci passed in '$PWD'."
}










ibm_audit_ci_cli_init "$@"; exit $?
