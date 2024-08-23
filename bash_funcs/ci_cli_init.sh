#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function ghciu_cli_init_before_config () {
  local ITEM= ADD=
  for ITEM in "$GHCIU_DIR" "$CI_PROJECT_DIR" "$CI_INVOKED_IN"; do
    ITEM+='/node_modules/.bin/'
    [ -d "$ITEM" ] || continue
    ITEM="${ITEM%/}"
    [[ ":$PATH:" == *":$ITEM:"* ]] && continue
    ADD+="$ITEM:"
  done
  if [ -n "$ADD" ]; then
    PATH="$ADD$PATH"
    export PATH
  fi

  source_available_rc_files "$GHCIU_DIR"/cfg || return $?
  [ . -ef "$GHCIU_DIR" ] || source_available_rc_files cfg || return $?
}


function in_func () {
  case "$1" in
    eval ) eval "shift 2; $2";;
    * ) "$@";;
  esac || return $?$(echo W: "$FUNCNAME $* failed (rv=$?)" >&2)
}


function source_these_files () {
  local ARGS="$1"; shift
  local ITEM=
  for ITEM in "$@"; do
    [ -f "$ITEM" ] || [[ "$ITEM" != *'*'* ]] || continue
    in_func source -- "$ITEM" $ARGS || return $?
  done
}


function source_additional_bash_funcs_files () {
  local DONE=()
  local MAYBE= CHECK=
  while [ "$#" -ge 1 ]; do
    MAYBE="$1"; shift
    case "$MAYBE" in
      '' ) continue;;
      --had=* ) DONE+=( "${MAYBE#*=}" ); continue;;
      -* ) echo E: $FUNCNAME: "Unsupported option: $MAYBE" >&2; return 4;;
    esac
    for MAYBE in "$MAYBE"/{bash_,ghciu_}funcs; do
      # [ -d "$MAYBE" ] || echo D: $FUNCNAME: "skip (not dir): $MAYBE"
      [ -d "$MAYBE" ] || continue
      for CHECK in "${DONE[@]}"; do
        [ "$MAYBE" -ef "$CHECK" ] || continue
        # echo D: $FUNCNAME: "skip (same as $CHECK): $MAYBE"
        MAYBE=
        break
      done
      [ -n "$MAYBE" ] || continue
      source_these_files --lib "$MAYBE"/*.sh || return $?$(
        echo E: $FUNCNAME: "Failed to source files from $MAYBE" >&2)
      DONE+=( "$MAYBE" )
      # echo D: $FUNCNAME: "sourced: $MAYBE"
    done
  done
}


function source_available_rc_files () {
  local RC= # NB: Do not re-declare CFG!
  for RC in "$@"; do
    for RC in "$RC".{local,@"$HOSTNAME"}; do
      source_these_files --config "$RC"{.,/}*.rc || return $?
    done
  done
}


function ghciu_decide_logfile_name () {
  local TOPIC="$1"
  case "$TOPIC" in
    '' ) TOPIC='no_logfile_topic_given';;
    *.pl | \
    *.py | \
    *.sed | \
    *.sh | \
    '' ) TOPIC="$(basename -- "${TOPIC%.*}")";;
  esac

  local SITE= LOGDIR=
  local CANDIDATES=()
  for SITE in "@$HOSTNAME" local; do
    for LOGDIR in "$CI_INVOKED_IN" "$CI_PROJECT_DIR"; do
      for LOGDIR in "$LOGDIR"/{.ghciu/,,tmp.}logs."$SITE"; do
        CANDIDATES+=( "$LOGDIR" )
      done
    done
  done

  # Add a fallback log dir. That will become the default if none of the above
  # was found. It may coincide with a prior candidate, which can be useful to
  # prioritize it if it exists, and still have it as fallback (to be created)
  # if none of the lower priority candidates exist.
  CANDIDATES+=( "$CI_PROJECT_DIR/.ghciu/logs.$SITE" )
  # printf -- 'log? <%s>\n' "${CANDIDATES[@]}" | nl -ba >&2

  for LOGDIR in "${CANDIDATES[@]}"; do [ -d "$LOGDIR" ] && break; done
  echo "$LOGDIR/$TOPIC.log"
}


function ghciu_magic_cilog_tee () {
  case "$1" in
    '' | /dev/null ) ;;
    /dev/stdout ) exec 2>&1;;
    /dev/stderr ) exec >&2;;
    * ) exec &> >(tee -- "$1");;
  esac
  shift
  "$@"; return $?
}

















return 0
