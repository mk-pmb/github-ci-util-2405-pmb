#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function gather_ci_run_meta () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFPATH="$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")" # busybox
  source -- "$SELFPATH"/lib_report.sh --lib || return $?

  local ATTEMPT_META='tmp.ci-attempt-meta.json'
  local SUITE_META='tmp.check-suite-meta.json'
  local CI_RUN_HTML_ORIG='tmp.check-suite-meta.html'
  local CI_RUN_HTML_NORMSP='tmp.check-suite-meta.normsp.html'
  local JOBS_MENU_HTML='tmp.jobs-menu.html'
  local JOB_NAME_LINKS='tmp.job-name-link-urls.txt'
  [ -n "$GITHUB_REPOSITORY" ] || return 4$(
    echo E: 'Empty GITHUB_REPOSITORY!' >&2)

  wget --version >/dev/null || lib_report__panic 'No wget!'

  case "$1" in
    '' ) ;;

    detect_job_id | \
    '' ) "$FUNCNAME"__"$@"; return $?;;

    * ) echo E: $FUNCNAME: "Unexpected CLI argument: $1" >&2; return 4;;
  esac

  cd -- "$GITHUB_ACTION_PATH" || return $?
  gather_ci_run_meta__fallible || return $?$(echo E: >&2 \
    "Gathering meta data failed. The API may have changed in a way that" \
    "ghciu is not compatible with yet. Maybe you need to update it," \
    "or run a newer version of its install action.")
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
  local ATTEMPT_URL="https://api.github.com/repos/$GITHUB_REPOSITORY$(
    )/actions/runs/$GITHUB_RUN_ID/attempts/$GITHUB_RUN_ATTEMPT"
  gather_ci_run_meta__wget "$ATTEMPT_META" -- "$ATTEMPT_URL" \
    || return $?$(echo E: "Failed to download $ATTEMPT_URL" >&2)
  # FMT=json ghciu_stepsumm_dump_file "$ATTEMPT_META" --count-lines

  local ATTEMPT_ID="$(jq .id -- "$ATTEMPT_META")"
  value_mustbe_simple_integer 'E: Unable to determine attempt ID:' \
    "$ATTEMPT_ID" ge:1 || return $?

  local SUITE_URL="https://api.github.com/repos/$GITHUB_REPOSITORY$(
    )/commits/$GITHUB_SHA/check-suites"
  local SUITE_URL="https://api.github.com/repos/$GITHUB_REPOSITORY$(
    )/actions/runs/$GITHUB_RUN_ID/attempts/$GITHUB_RUN_ATTEMPT"
  gather_ci_run_meta__wget "$SUITE_META" -- "$SUITE_URL" \
    || return $?$(echo E: "Failed to download $SUITE_URL" >&2)
  # FMT=json ghciu_stepsumm_dump_file "$SUITE_META" --count-lines

  local WF_BN="$(basename -- "$GITHUB_WORKFLOW")"
  WF_BN="${WF_BN%.yaml}"
  WF_BN="${WF_BN%.yml}"
  [ -n "$WF_BN" ] || return 3$(
    echo E: "Unable to determine workflow basename!" >&2)

  # local RAW_LOG_URL="$(jq --raw-output .logs_url -- "$ATTEMPT_META")"
  # ^-- Useless in a browser: Access will be denied without token header.
  local CI_JOB_ID=
  local RAW_LOG_URL=
  gather_ci_run_meta__detect_job_id || true
  local LOG_LINK='&#x1F4DC;' # scroll
  [ -n "$RAW_LOG_URL" ] || LOG_LINK="&#x26CD;" # disabled car
  LOG_LINK='<a href="'"${RAW_LOG_URL:-#no_job_id_detected}"'"><img '$(
    )'src="about:blank" align="right" alt="'"$LOG_LINK"'"></a>'
  [ -n "$RAW_LOG_URL" ] || LOG_LINK="<del>$LOG_LINK</del>"
  # ^-- We have to abuse ancient img align because GitHub's HTML sanitization
  #     will eat any modern solution.
  echo "$LOG_LINK" >>"$GITHUB_STEP_SUMMARY"

  printf -- '%s=%q\n' \
    GHCIU_WORKFLOW_BASENAME "$WF_BN" \
    GHCIU_ATTEMPT_ID "$ATTEMPT_ID" \
    GHCIU_JOB_ID "$CI_JOB_ID" \
    >>"$GITHUB_ENV"
  # ghciu_stepsumm_dump_file "$GITHUB_ENV" --title 'GITHUB_ENV' --count-lines
}


function gather_ci_run_meta__detect_job_id () {
  value_mustbe_simple_integer 'E: Unable to determine attempt ID:' \
    "$ATTEMPT_ID" ge:1 || return $?
  local CI_RUN_URL="https://github.com/$GITHUB_REPOSITORY/$(
    )actions/runs/$ATTEMPT_ID"
  [ -s "$CI_RUN_HTML_ORIG" ] \
    || gather_ci_run_meta__wget "$CI_RUN_HTML_ORIG" -- "$CI_RUN_URL" \
    || return $?$(echo E: "Failed to download $CI_RUN_URL" >&2)

  <"$CI_RUN_HTML_ORIG" tr -s '\r\n \t' ' ' >"$CI_RUN_HTML_NORMSP" || return $?
  LANG=C sed -zrf <(echo '
    s~<h2\b[^<>]* class="ActionList-sectionDivider-title"[^<>]*>\s*~\n~g
    ') -- "$CI_RUN_HTML_NORMSP" | grep -Pie '^job' >"$JOBS_MENU_HTML"

  grep -oPe '<a [^<>]*>' -- "$CI_RUN_HTML_NORMSP" \
    | sed -nre 's! id="workflow-job-name-!\t!p' | sed -rf <(echo '
    s~^([^\t]*)\t([^"]+)"~\2\t\1~
    s~ data-[a-z-]+="[^"]*"~~g
    ') | tee -- tmp.job-name-link-tags.html | sed -nrf <(echo '
    s~ href="[^" \n]+/actions/runs/[0-9]+/job/([0-9]+)~\n\1\n~
    s~^(\S+)\t[^\n]*\n([0-9]+)\n.*$~<<\1>>\2~p
    ') >"$JOB_NAME_LINKS"

  local VAL="<<$WF_BN.$GITHUB_JOB>>"$'\n'"<<$GITHUB_JOB>>"
  CI_JOB_ID="$(grep -m 1 -Fe "$VAL" -- "$JOB_NAME_LINKS")"
  CI_JOB_ID="${CI_JOB_ID##*>>}"
  local E='E: Unable to determine CI job ID:'
  if value_mustbe_simple_integer "$E" "$CI_JOB_ID" ge:1; then
    RAW_LOG_URL="https://github.com/$GITHUB_REPOSITORY/commit/$(
      )$GITHUB_SHA/checks/$CI_JOB_ID/logs"
  else
    # ghciu_stepsumm_dump_file "$JOBS_MENU_HTML"
    # ghciu_stepsumm_dump_file "$JOB_NAME_LINKS"
    return 2
  fi
}










gather_ci_run_meta "$@"; exit $?
