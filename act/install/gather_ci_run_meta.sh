#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function gather_ci_run_meta () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFPATH="$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")" # busybox
  source -- "$SELFPATH"/lib_report.sh --lib || return $?

  local META_TMP="${CFG[logsdir]}/$FUNCNAME.$GITHUB_RUN_ATTEMPT"
  mkdir --parents -- "$META_TMP"
  [ -n "$GITHUB_REPOSITORY" ] || return 4$(
    echo E: 'Empty GITHUB_REPOSITORY!' >&2)
  local REPO_URL="https://github.com/$GITHUB_REPOSITORY"

  wget --version >/dev/null || lib_report__panic 'No wget!'

  case "$1" in
    '' ) ;;

    detect_job_checknum | \
    '' ) "$FUNCNAME"__"$@"; return $?;;

    * ) echo E: $FUNCNAME: "Unexpected CLI argument: $1" >&2; return 4;;
  esac

  cd -- "$META_TMP" || return $?
  env | sort -V >gh-runner-env.txt
  cp --no-target-directory -- "$GITHUB_EVENT_PATH" gh-event.json
  npm config list --long --json >npm.cfg.json
  ( cd .. && npm version --json ) >npm.ver.json

  local RV=
  gather_ci_run_meta__fallible; RV=$?

  cp --no-target-directory -- "$GITHUB_ENV" gh-env-file.json

  [ "$RV" == 0 ] || echo E: >&2 \
    "Gathering meta data failed. The API may have changed in a way that" \
    "ghciu is not compatible with yet. Maybe you need to update it," \
    "or run a newer version of its install action."
  return "$RV"
}


function gather_ci_run_meta__wget () {
  local SAVE="$1"; shift
  local WGET=(
    wget
    --quiet

    --tries=1
    --timeout=10
    # ^-- We can expect the GitHub API to be really quick for the types
    #   of requests we're doing. If it hangs, it's probably an outage,
    #   and thus no use in wasting the user's time.

    --output-document="$SAVE"
    )
  "${WGET[@]}" "$@"; return $?
}


function gather_ci_run_meta__fallible () {
  local API_URL_REPO="https://api.github.com/repos/$GITHUB_REPOSITORY"
  local API_URL_RUN="$API_URL_REPO/actions/runs/$GITHUB_RUN_ID"
  local API_URL_ATT="$API_URL_RUN/attempts/$GITHUB_RUN_ATTEMPT"

  local -A META=(
    [wflow_title]="$GITHUB_WORKFLOW" # defaults to its YAML section key.
    )
  local KEY= VAL=
  VAL='
    uts=%s
    long=%FT%T
    short=%y%m%d-%H%M%S
    '
  for VAL in $VAL; do
    KEY="${VAL%%=*}"
    VAL="${VAL#*=}"
    VAL="$(printf -- "%($VAL)T" -2)"
    META[wflow_start_$KEY]="$VAL"
  done

  VAL="$GITHUB_WORKFLOW_REF"
  META[wflow_ref_at]="${VAL#*@}"; VAL="${VAL%%@*}"
  META[wflow_repo_owner]="${VAL%%/*}"; VAL="${VAL#*/}"
  META[wflow_repo_name]="${VAL%%/*}"; VAL="${VAL#*/}"
  META[wflow_file]="$VAL"
  VAL="$(basename -- "$VAL")"
  VAL="${VAL%.yaml}"
  VAL="${VAL%.yml}"
  META[wflow_bfn]="$VAL"

  META[abbrev_sha]="${GITHUB_SHA:0:7}"
  META[trace_job]="$GITHUB_JOB.${GITHUB_SHA:0:7}.$GITHUB_RUN_ATTEMPT"

  META[job_checknum]=
  gather_ci_run_meta__detect_job_checknum || true

  VAL="${META[job_checknum]}"
  [ -z "$VAL" ] || VAL="$REPO_URL/commit/$GITHUB_SHA/checks/$VAL/logs"
  lib_report__link_badge "url=$VAL" 'icon=%scroll' \
    'error_name=no_job_checknum_detected'

  local RLS_TAG="$GHCIU_STEPSUMM_RELEASE_TAG"
  [ -z "$RLS_TAG" ] || lib_report__link_badge \
    "url=$REPO_URL/releases/tag/$RLS_TAG" 'icon=%package'

  KEY="$(printf -- '%s\n' "${!META[@]}" | sort --version-sort)"
  for KEY in $KEY; do
    VAL="${META[$KEY]}"
    printf -- 'GHCIU_%s=%q\n' "${KEY^^}" "$VAL" >>"$GITHUB_ENV"
    printf -- '[%s]=%q\n' "$KEY" "$VAL" >>ci-run-meta.bash-dict.txt
  done
}


function gather_ci_run_meta__detect_job_checknum () {
  gather_ci_run_meta__wget gh-attempt-jobs.json -- "$API_URL_ATT/jobs" ||
    return $?$(echo E: $FUNCNAME: "Failed to download jobs info from API" >&2)
  <gh-attempt-jobs.json jq --raw-output '.jobs[] | .id, .name' |
    sed -re 'N;s~\n~\t~;/\)$/!s~$~ ~' >gh-job-titles.tsv

  ##### 2026-04-10: Job title ("name") vs. YAML job section key: ##### #####
  # Unfortunately, we only have the job title (the misleadingly named
  # `name` property of the job) easily available, which fortunately does
  # default to the YAML section key if missing.
  # In case of the matrix strategy, a space character and the arguments
  # (wrapped in parens) are appended to the title.
  # To determine the section key, we could try and look it up in the workflow
  # file, but even that would be unreliable because job titles could be
  # duplicate or even misleading.
  # For now, if you have to use job titles different from their section key,
  # make sure they start with the section key and a space character.
  # (And be conservative about what characters you use for the section key.)

  local VAL=$'\t'"$GITHUB_JOB " ERR=
  VAL="$(grep -Fe "$VAL" -- gh-job-titles.tsv | cut -sf 1)"
  case "$VAL" in
    '' ) ERR='Cannot find any job';;
    *$'\n'* ) ERR='Found too many jobs';;
    *[^0-9]* ) ERR='Found non-digit character in job number for job';;
    [0-9]* ) META[job_checknum]="$VAL"; return 0;;
    * ) # Neither digit nor non-digit nor empty => broken shell
      ERR='Exotic control flow bug when looking up the job';;
  esac
  echo E: $FUNCNAME: "$ERR titled '$GITHUB_JOB'." >&2
  return 4
}












gather_ci_run_meta "$@"; exit $?
