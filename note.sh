#!/usr/bin/env bash
# Copyright © 2022-2024 Kan Vladislav <thek4n@yandex.ru>. All rights reserved.


set -ueo pipefail
shopt -s nullglob

: "${XDG_DATA_HOME:=$HOME/.local/share}"
readonly CONFIGFILE="$XDG_DATA_HOME/note/notes-storage-path"
readonly DEFAULT_PREFIX="$HOME/.notes"

: "${XDG_RUNTIME_DIR:=$HOME/.local/state}"
readonly LOCKFILE="$XDG_RUNTIME_DIR/note/lock"

readonly ORIGIN="origin"
readonly BRANCH="master"

declare PROGRAM
PROGRAM="$(basename "$0")"
readonly PROGRAM

readonly FZF="fzf"
readonly FZF_PAGER="bat"

readonly GRAPH_MARK="$XDG_DATA_HOME/note/graph.hash"

readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NOCOLOR='\033[0m'

readonly OK_MESSAGE="${GREEN}OK${NOCOLOR}"
readonly WARN_MESSAGE="${YELLOW}WARN${NOCOLOR}"
readonly ERROR_MESSAGE="${RED}ERROR${NOCOLOR}"


readonly INVALID_ARG_CODE=2
readonly INVALID_OPT_CODE=3
readonly INVALID_STATE_CODE=4


die() {
    echo "$PROGRAM: Error: $1" 1>&2
    exit $2
}


cmd_usage() {
    echo "Usage:
    $PROGRAM help
        Show this text
    $PROGRAM init [-p PATH] [-r REMOTE]
        Initialize new note storage in PATH(default=~/.notes), if REMOTE specified, pulls notes from there
    $PROGRAM version
        Print version and exit
    $PROGRAM edit (PATH_TO_NOTE)
        Creates or edit existing note with \$EDITOR, after save changes by git
    $PROGRAM today
        Creates or edit note with name like daily/06-01-24.md
    $PROGRAM fedit
        Find note by fzf and edit with \$EDITOR
    $PROGRAM show (PATH_TO_NOTE)
        Show note in terminal by \$PAGER
    $PROGRAM rm (PATH_TO_NOTE)
        Removes note
    $PROGRAM mv (PATH_TO_NOTE) (new-note-name)
        Rename note
    $PROGRAM ln (PATH_TO_NOTE) (link-name)
        Create symbolic link
    $PROGRAM ls [PATH_TO_NOTE]...
        List notes
    $PROGRAM graph
        Make graph of notes relations in PDF format
    $PROGRAM mkdir (PATH_TO_DIR)
        Creates new directory and subdirs
    $PROGRAM tree [PATH_TO_SUBDIR]
        Show notes in storage or subdir
    $PROGRAM find (NOTE_NAME)
        Find note with name
    $PROGRAM grep (PATTERN)
        Find notes by pattern
    $PROGRAM checkhealth
        Check installed dependencies and initialized storage
    $PROGRAM sync
        Pull changes from remote note storage(in case of conflict, accepts yours changes)
    $PROGRAM git ...
        Proxy commands to git
    $PROGRAM --prefix
        Prints to stdout current notes storage
    $PROGRAM export
        Export notes in tar.gz format, redirect output in stdout (use $PROGRAM export > notes.tar.gz)" >&2
    exit $1
}

cmd_version() {
    echo "%%VERSION%%"
    exit 0
}

_ask_user() {
    local answer
    local question="$1"
    local default_value="$2"
    read -rp "$question (default=$default_value): " answer

    if [ -z "$answer" ]; then
        answer="$default_value"
    fi

    echo "$answer"
}

_is_yes() {
    [[ "$1" == [Yy]* ]]
}

_validate_arg() {
	if [[ $2 == -* ]]; then
		die "Option $1 requires an argument" $INVALID_ARG_CODE
	fi
}

cmd_init() {
    local remote_storage
    remote_storage=""
    PREFIX="$DEFAULT_PREFIX"

    while getopts ":p:r:" opt; do
        case "$opt" in
            p)
                _validate_arg "-$opt" "$OPTARG"
                PREFIX="$(realpath -m "$OPTARG")"
            ;;
            r)
                _validate_arg "-$opt" "$OPTARG"
                remote_storage="$OPTARG"
            ;;
            :)
                die "Option -$OPTARG requires an argument" $INVALID_ARG_CODE
            ;;
            \?)
                die "Invalid option: -$OPTARG" $INVALID_OPT_CODE
            ;;
        esac
    done

    mkdir -p "$(dirname "$CONFIGFILE")"
    echo "$PREFIX" > "$CONFIGFILE"

    if [ ! -d "$PREFIX" ]; then
        mkdir "$PREFIX"
    fi
    git init -b "$BRANCH" "$PREFIX"
    if [ -n "$remote_storage" ]; then
        git -C "$PREFIX" remote add "$ORIGIN" "$remote_storage"
        cmd_sync
    fi
    exit 0
}

__is_note_storage_initialized() {
    [ -r "$CONFIGFILE" ]
    local prefix
    prefix="$(cat "$CONFIGFILE")"
    [ -d "$prefix" ]
    [ -w "$prefix" ]
    [ -w "$prefix/.git" ]
}

die_if_not_initialized() {
    if ! __is_note_storage_initialized; then
        die "You need to initialize: $PROGRAM init [-p PATH]" $INVALID_STATE_CODE
    fi
}

die_if_name_not_entered() {
    test -n "$1" || die "Note name wasn\`t entered" $INVALID_ARG_CODE
}

cmd_git() {
    git -C "$PREFIX" "$@"
}

git_add() {
    cmd_git add "$1"
}

git_commit() {
    cmd_git commit -m "$1" 1>/dev/null
}

die_if_invalid_path() {
    if [[ "$1" =~ ".." ]]; then
        die "Path can\`t contains '..'" $INVALID_ARG_CODE
    fi

    if [[ "$1" = /* ]]; then
        die "Path can\`t start from '/'" $INVALID_ARG_CODE
    fi
}

_is_depends_installed() {
    command -v "$1" &>/dev/null
}

die_if_depends_not_installed() {
    _is_depends_installed "$1" || die "'$1' not installed. Use '$PROGRAM checkhealth'." $INVALID_STATE_CODE
}

_is_variable_set() {
    [[ -v "$1" ]]
}

die_if_variable_name_not_set() {
    if ! _is_variable_set "$1"; then
        die "Variable '$1' not defined" $INVALID_STATE_CODE
    fi
}

_find_command() {
    command -v "$1" 1>/dev/null
}

die_if_command_invalid() {
    if ! _find_command "$1"; then
        die "$2 ($1) is invalid" $INVALID_STATE_CODE
    fi
}

cmd_edit() {
    die_if_name_not_entered "$1"
    die_if_invalid_path "$1"
    die_if_variable_name_not_set "EDITOR"
    die_if_command_invalid "${EDITOR%% *}" "EDITOR"  # check only first word of variable

    test -d "$PREFIX/$1" && die "Can\`t edit directory '$1'" $INVALID_ARG_CODE

    local _new_note_flag
    if [ ! -e "$PREFIX/$1" ]; then
        echo "Creating new note '$1'"
        _new_note_flag=true
    else
        _new_note_flag=false
    fi

    local _new_dir_flag
    _new_dir_flag=false

    local _DIRNAME
    _DIRNAME="$(dirname "$1")"

    if [ ! -d "$PREFIX/$_DIRNAME" ]; then
        mkdir -p "$PREFIX/$_DIRNAME"
        _new_dir_flag=true
    fi

    $EDITOR "$PREFIX/$1"

    if [ -e "$PREFIX/$1" ]; then
        if $_new_note_flag; then
            git_add "$1"
            git_commit "Created new note $1 by $HOSTNAME"
            echo "Note '$1' has been created"
        elif [ -n "$(cmd_git diff "$1")" ]; then
            git_add "$1"
            git_commit "Edited note $1 by $HOSTNAME"
            echo "Note '$1' has been edited"
        else
            echo "Note '$1' wasn\`t edited"
        fi
    else
        echo "New note '$1' wasn\`t created"
        if $_new_dir_flag; then
            # removes only empty dirs recursively
            cd "$PREFIX"
            rmdir -p "$_DIRNAME"
        fi
    fi
}

cmd_today() {
    cmd_edit "daily/$(date "+${DATE_FMT:-%d-%m-%y}").md"
}

cmd_fedit() {
    die_if_depends_not_installed "$FZF"
    die_if_depends_not_installed "$FZF_PAGER"
    export FZF_DEFAULT_OPTS="\
        --no-multi \
        --no-sort \
        --preview-window right:60% \
        --bind ctrl-/:toggle-preview \
        --preview=\"$FZF_PAGER --plain --wrap=never --color=always $PREFIX/{}\""

    cmd_edit "$(cmd_complete_notes | $FZF --query "${1:-}")"
}

cmd_list() {
    die_if_invalid_path "$*"
    cd "$PREFIX"
    ls --color=always "$@"
}

cmd_show() {
    die_if_invalid_path "$1"
    die_if_name_not_entered "$1"
    die_if_variable_name_not_set "PAGER"
    die_if_command_invalid "${PAGER%% *}" "PAGER"

    test -e "$PREFIX/$1" || die "Note '$1' doesn\`t exist" $INVALID_ARG_CODE
    $PAGER "$PREFIX/$1"
    exit 0
}

cmd_proxy() {
    shift
    die_if_invalid_path "$*"


    cd "$PREFIX"
    local command="$1"
    
    "$command" "$@"

    git add .
    git ci -m ""

    exit 0
}

_die_if_locked() {
    if [ -e "$LOCKFILE" ]; then
        die "Seems another process is running. If not, just delete $LOCKFILE" $INVALID_STATE_CODE
    fi
}

_set_lock() {
    mkdir -p "$(dirname "$LOCKFILE")"
    touch "$LOCKFILE"
}

_release_lock() {
    rm "$LOCKFILE"
}

_is_repository_not_clean() {
    [[ -n "$(cmd_git status -s)" ]]
}

if [[ ! -v 1 ]]; then
    die "Type '$PROGRAM help' for usage" 1
fi

case "$1" in
    init) shift;            cmd_init         "$@" ;;
    help|--help|-h) shift;  cmd_usage 0      "$@" ;;
    version|-V) shift;      cmd_version      "$@" ;;
    checkhealth) shift;     cmd_checkhealth  "$@" ;;
esac


die_if_not_initialized
PREFIX="$(cat "$CONFIGFILE")"


if _is_repository_not_clean; then
    echo "$PROGRAM: WARNING: repository not clean!" 1>&2
fi


case "$1" in
    show) shift;      cmd_show         "$@" ;;
    ls) shift;        cmd_ls           "$@" ;;
    tree) shift;      cmd_tree         "$@" ;;
    find) shift;      cmd_find         "$@" ;;
    grep) shift;      cmd_grep         "$@" ;;
    graph) shift;     cmd_graph        "$@" ;;
    complete) shift;  cmd_complete     "$@" ;;
    --prefix) shift;  cmd_get_storage  "$@" ;;
esac


_die_if_locked
_set_lock
trap _release_lock ERR
trap _release_lock EXIT


case "$1" in
    edit) shift;      cmd_edit     "$@" ;;
    today) shift;     cmd_today    "$@" ;;
    fedit) shift;     cmd_fedit    "$@" ;;
    rm) shift;        cmd_delete   "$@" ;;
    mv) shift;        cmd_rename   "$@" ;;
    ln) shift;        cmd_ln       "$@" ;;
    mkdir) shift;     cmd_mkdir    "$@" ;;
    export) shift;    cmd_export   "$@" ;;
    sync) shift;      cmd_sync     "$@" ;;
    git) shift;       cmd_git      "$@" ;;

    *)                cmd_usage 1  "$@" ;;
esac
exit 0
