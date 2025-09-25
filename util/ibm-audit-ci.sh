#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function ibm_audit_ci_cli_init () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFPATH="$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")" # busybox
  source -- "$SELFPATH"/../act/install/lib_report.sh --lib || return $?

  [ -n "$CI" ] || return 0$(
    echo W: "Skipping audit-ci because env var CI is empty!" >&2)

  local KEY= VAL=
  local FLAGS=",${IBM_AUDIT_CI_FLAGS// /,},"
  local AC_APPNAME='IBM audit-ci'
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

  local BADGE=(
    lib_report__link_badge
    {error_,}title="audit-ci: ${PWD##*/}"
    icon=%shield
    error_icon=%emergency
    error_name=audit-ci
    )

  echo D: "Running $AC_APPNAME in '$PWD' with config '$AC_CFG'."
  if npx 'audit-ci@^'"$AC_VER" "${AC_OPT[@]}"; then
    case "$FLAGS" in
      *,no_success_badge,* ) ;;
      * ) "${BADGE[@]}" url=: >/dev/null;;
    esac
    echo D: "$AC_APPNAME passed in '$PWD'."
    return 0
  fi

  "${BADGE[@]}" >/dev/null
  echo E: "$AC_APPNAME failed in '$PWD'!" >&2
  return 8
}










ibm_audit_ci_cli_init "$@"; exit $?
