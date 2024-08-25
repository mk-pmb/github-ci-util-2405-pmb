#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function purge_old_wfruns () {
  local -A CFG=()
  eval "CFG=( $(json_to_bash_dict_init "$INPUTS_JSON" ) )"
  SECONDS=0
  local PROGNAME='purge-old-workflow-runs'

  local E="E: $PROGNAME:"
  value_mustbe_simple_integer "$E GHCIU_JOB_ID" "$GHCIU_JOB_ID" \
    ge:1 || return $?

  local KEY= VAL=
  local OLD="${CFG[older_than]}"
  [ -n "$OLD" ] || return 4$(
    echo E: $PROGNAME: 'Missing option: older_than' >&2)
  [ -z "${OLD//[A-Za-z0-9:. -]/}" ] || return 4$(
    echo E: $PROGNAME: 'Option "older_than" contains unsupported characters.' \
    'Acceptable characters are letters (A-Z, a-z), digits (0-9),' \
    'colon (:), full stop (.), space and minus (-).' >&2)
  OLD="$(date +'%FT%TZ' --utc --date="$OLD")"
  [ -n "$OLD" ] || return 4$(echo E: $PROGNAME: >&2 \
    'Unsupported date/time format in option "older_than".')
  echo D: $PROGNAME: "Effective older_than date: $OLD"

  E+=" Config error: Option"
  local OVERALL_TIMEOUT="${CFG[overall_timeout_seconds]}"
  value_mustbe_simple_integer "$E overall_timeout_seconds" \
    "$OVERALL_TIMEOUT" ge:1 || return $?

  value_mustbe_simple_integer "$E api_cooldown_seconds" \
    "${CFG[api_cooldown_seconds]}" ge:1 || return $?
  value_mustbe_simple_integer "$E max_failed" \
    "${CFG[max_failed]}" ge:0 || return $?
  value_mustbe_simple_integer "$E max_purged" \
    "${CFG[max_purged]}" ge:0 || return $?

  # Normalize the word lists
  cfg_include_exclude_wordlists_prepare CFG \
    branches_ \
    conclusions \
    trigger_events \
    workflows_ \
    ;

  local RUNS_PER_PAGE="${CFG[api_pagesize]}"
  value_mustbe_simple_integer "$E api_pagesize" \
    "$RUNS_PER_PAGE" ge:1 || return $?

  local CONCLU="${CFG[conclusions]}"
  [ -n "$CONCLU" ] || return 4$(echo "$E conclusions is empty!" >&2)
  [ "${CONCLU// /}" != '*' ] || return 4$(
    echo "$E conclusions must be explicit!" >&2)
  CONCLU=" ${CONCLU} "

  local DATA_COLUMNS=(
    created_at # should be first for sorting, so we delete oldest runs first.
    event
    path
    head_branch
    conclusion
    id
    )

  local RUNS_BASEURL="https://api.github.com/repos/$GITHUB_REPOSITORY$(
    )/actions/runs"
  local RUNS_SEARCH="$RUNS_BASEURL?status=completed&created=%3C$OLD"
  RUNS_SEARCH+="&per_page=$RUNS_PER_PAGE&page="
  local CURPG_NUM=1
  local N_TOTAL_PAGES=
  local CURPG_SAVE= CURPG_DATA=
  purge_old_wfruns__download_current_runs_page || return $?
  local N_TOTAL_RUNS="$(jq .total_count -- "$CURPG_SAVE")"
  if [ "$N_TOTAL_RUNS" == 0 ]; then
    VAL="$PROGNAME: No too-old runs were found."
    echo $'\n'"$VAL"$'\n' >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
    echo D: "$VAL"
    return 0
  fi
  [ "${N_TOTAL_RUNS:-0}" -ge 1 ] || return 4$(
    echo E: $PROGNAME: 'Failed to count results.' >&2)
  (( N_TOTAL_PAGES = ( ( N_TOTAL_RUNS - 1 ) / RUNS_PER_PAGE ) + 1 ))
  CURPG_NUM="$N_TOTAL_PAGES"
  local N_RUNS_PURGED=0
  local N_RUNS_FAILED=0
  local N_RUNS_SKIPPED=0

  local CURL_CMD=(
    curl
    --silent
    --include # Include the HTTP response headers in the output.
    --location
    --request DELETE
    --header "Accept: application/vnd.github+json"
    --header "Authorization: Bearer ${CFG[api_token]:-$GITHUB_TOKEN}"
    --header "X-GitHub-Api-Version: 2022-11-28"
    --
    )

  while [ "$CURPG_NUM" -ge 1 ]; do
    purge_old_wfruns__download_current_runs_page || return $?
    # ghciu_stepsumm_dump_textblock details_file "$CURPG_DATA"
    purge_old_wfruns__process_tsv_runs_list <"$CURPG_DATA" || return $?
    (( CURPG_NUM -= 1 ))
  done

  VAL="$PROGNAME: Done. $N_TOTAL_RUNS total, $N_RUNS_PURGED purged, $(
    )$N_RUNS_FAILED failed, $N_RUNS_SKIPPED skipped."
  echo $'\n'"$VAL"$'\n' >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
  echo D: "$VAL"
}

function purge_old_wfruns__api_cooldown () {
  [ "$SECONDS" -le "$OVERALL_TIMEOUT" ] || return 4$(echo E: $PROGNAME: >&2 \
    echo E: $PROGNAME: 'Abort: Exceeded overall_timeout_seconds.')
  sleep "${CFG[api_cooldown_seconds]}s" || return 4$(echo E: $PROGNAME: >&2 \
    "Failed to let the API cool down after downloading $RUNS_URL")
}


function purge_old_wfruns__download_current_runs_page () {
  [ -z "$N_TOTAL_PAGES" ] || purge_old_wfruns__api_cooldown || return $?
  CURPG_SAVE="tmp.runs-pg-$CURPG_NUM.json"
  CURPG_DATA="tmp.runs-pg-$CURPG_NUM.tsv"
  local RUNS_URL="$RUNS_SEARCH$CURPG_NUM"
  if [ -s "$CURPG_SAVE" ]; then
    echo D: $PROGNAME: "We already have page $CURPG_NUM."
    return 0
  fi
  echo D: $PROGNAME: "Downloading list of too-old CI runs:" \
    "page $CURPG_NUM of ${N_TOTAL_PAGES:-unknown}."
  wget --quiet --output-document="$CURPG_SAVE" -- "$RUNS_URL" || return $?$(
    echo E: $PROGNAME: "Failed to download $RUNS_URL" >&2)
  local JQ="${DATA_COLUMNS[*]}"
  JQ="${JQ// /, .}"
  JQ=".workflow_runs[] | [.$JQ] | @tsv"
  jq --raw-output "$JQ" -- "$CURPG_SAVE" \
    | sort --version-sort >"$CURPG_DATA" || return $?$(
    echo E: $PROGNAME: "Failed to extract data from $RUNS_URL" >&2)
}


function purge_old_wfruns__process_tsv_runs_list () {
  local -A ROW=()
  local BUF= KEY= VAL= WFBN= SKIP= RV= HEAD= BODY=
  while IFS= read -r BUF; do
    [ "$N_RUNS_FAILED" -lt "${CFG[max_failed]}" ] || return 4$(
      echo E: $PROGNAME: "Abort: We have encountered $N_RUNS_FAILED" \
        "≥ max_failed = ${CFG[max_failed]} failures." >&2)
    [ "$N_RUNS_PURGED" -lt "${CFG[max_purged]}" ] || return 4$(
      echo E: $PROGNAME: "Abort: We have purged $N_RUNS_PURGED" \
        "≥ max_purged = ${CFG[max_purged]} workflow runs." >&2)

    purge_old_wfruns__api_cooldown || return $?
    ROW=()
    for KEY in "${DATA_COLUMNS[@]}"; do
      VAL="${BUF%%$'\t'*}"
      [ "$VAL" == "$BUF" ] && BUF=
      BUF="${BUF#*$'\t'}"
      ROW["$KEY"]="$VAL"
    done
    [ -z "$BUF" ] || return $?$(
      echo E: $PROGNAME: "Unexpected left-over TSV column data: $BUF" >&2)
    VAL=
    local -p | grep ROW

    SKIP=
    [ "${ROW[id]}" != "$GHCIU_JOB_ID" ] \
      || [[ "$CONCLU" == *,SELF,* ]] || SKIP+=',SELF'
    [[ "$CONCLU" == *" ${ROW[conclusion]} "* ]] || SKIP+=',conclusion'
    [ "${CFG[trigger_events]}" == '*' ] || \
      [[ "${CFG[trigger_events]}" == *" ${ROW[event]} "* ]] || SKIP+=',event'

    cfg_include_exclude_wordlists_check CFG \
      branches_ "${ROW[head_branch]}" || SKIP+=',branch'

    WFBN="$(basename -- "${ROW[path]}")"
    WFBN="${WFBN%.yaml}"
    WFBN="${WFBN%.yml}"
    cfg_include_exclude_wordlists_check CFG \
      workflows_ "$WFBN" || SKIP+=',workflow'

    KEY="$RUNS_BASEURL/${ROW[id]}"
    if [ -n "$SKIP" ]; then
      (( N_RUNS_SKIPPED += 1 ))
      echo D: $PROGNAME: "Skip (${SKIP#,}): $KEY"
      continue
    fi

    BUF="$("${CURL_CMD[@]}" "$KEY")"
    RV=$?
    BUF="${BUF//$'\r'/}"
    if [ "$RV" != 0 ]; then
      echo W: $PROGNAME: "Failed to delete $KEY (rv=$RV)" >&2
      echo W: $PROGNAME: "API response as base64: $(
        base64 --wrap=9009009009 <<<"$BUF")" >&2
      (( N_RUNS_FAILED += 1 ))
      continue
    fi

    HEAD="${BUF%%$'\n\n'*}"
    [ "$HEAD" == "$BUF" ] && BUF=
    BODY="${BUF#*$'\n\n'}"

    if [ "${HEAD:0:11}" == 'HTTP/2 404 ' ]; then
      echo D: $PROGNAME: "Missing in action: $KEY"
      (( N_RUNS_PURGED += 1 ))
      continue
    fi
    if [ -z "$BODY" -a "${HEAD:0:11}" == 'HTTP/2 204 ' ]; then
      echo D: $PROGNAME: "Deleted: $KEY"
      (( N_RUNS_PURGED += 1 ))
      continue
    fi

    case "$BODY" in
      '{'*'"message":'*'}'* )
        echo E: $PROGNAME: 'Unexpected API reply:' \
          "[${HEAD%%$'\n'*}] ${BODY//$'\n'/ }" >&2
        return 4;;
    esac

    echo E: $PROGNAME: "Unexpected API reply" >&2
    echo W: $PROGNAME: "API response headers (${#HEAD} bytes) as base64: $(
      base64 --wrap=9009009009 <<<"$HEAD")" >&2
    echo W: $PROGNAME: "API response body (${#BODY} bytes) as base64: $(
      base64 --wrap=9009009009 <<<"$BODY")" >&2
    return 4
  done
}

















purge_old_wfruns "$@"; exit $?
