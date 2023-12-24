#!/usr/bin/env bash
# Copyright © 2022-2023 Kan Vladislav <thek4n@yandex.ru>. All rights reserved.


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
    $PROGRAM fedit
        Find note by fzf and edit with \$EDITOR
    $PROGRAM show (PATH_TO_NOTE)
        Show note in terminal by \$PAGER
    $PROGRAM render (PATH_TO_NOTE)
        Render note in browser by grip in localhost:6751
    $PROGRAM rm (PATH_TO_NOTE)
        Removes note
    $PROGRAM mv (PATH_TO_NOTE) (new-note-name)
        Rename note
    $PROGRAM ls [PATH_TO_NOTE]...
        List notes
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
    exit 0
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
                PREFIX="$OPTARG"
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

_is_EDITOR_valid() {
    command -v "$EDITOR" >/dev/null
}

die_if_EDITOR_invalid() {
    if ! _is_EDITOR_valid; then
        die "EDITOR ($EDITOR) is invalid" $INVALID_STATE_CODE
    fi
}

cmd_edit() {
    die_if_name_not_entered "$1"
    die_if_invalid_path "$1"
    die_if_variable_name_not_set "EDITOR"
    die_if_EDITOR_invalid

    test -d "$PREFIX/$1" && die "Can\`t edit directory '$1'" $INVALID_ARG_CODE

    local last_modified_time
    if [ -e "$PREFIX/$1" ]; then
        last_modified_time="$(stat -c '%Y' "$PREFIX/$1")"
    else
        echo "Creating new note '$1'"
        last_modified_time=0
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
        if [ "$last_modified_time" != "$(stat -c '%Y' "$PREFIX/$1")" ]; then
            git_add "$1"
            git_commit "Edited note $1"
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

cmd_fedit() {
    die_if_depends_not_installed "$FZF"
    die_if_depends_not_installed "$FZF_PAGER"
    export FZF_DEFAULT_OPTS="\
        --no-multi \
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
    test -f "$PREFIX/$1" || die "Note '$1' doesn\`t exist" $INVALID_ARG_CODE
    $PAGER "$PREFIX/$1"
    exit 0
}

cmd_ls() {
    die_if_invalid_path "$*"
    if [ -z "$*" ]; then
        cmd_list
    else
        cmd_list "$@"
    fi
    exit 0
}

cmd_mkdir() {
    die_if_name_not_entered "$1"
    die_if_invalid_path "$1"

    mkdir -p "$PREFIX/$1"
}

cmd_tree() {
    local path
    path="${1:-.}"

    die_if_invalid_path "$path"
    die_if_depends_not_installed "tree"

    test -d "$PREFIX/$path" || die "'$path' not a directory" $INVALID_ARG_CODE
    cd "$PREFIX"

    tree -N -C --noreport "$path"
    exit 0
}

cmd_render() {
    die_if_name_not_entered "$1"
    die_if_depends_not_installed "grip"

    test -f "$PREFIX/$1" || die "Note '$1' doesn\`t exist" $INVALID_ARG_CODE
    echo "http://localhost:6751 in browser"
    grip -b "$PREFIX/$1" localhost:6751 1>/dev/null 2>/dev/null
    exit 0
}

cmd_delete() {
    die_if_invalid_path "$1"
    die_if_name_not_entered "$1"
    test -e "$PREFIX/$1" || die "Note '$1' doesn\`t exist" $INVALID_ARG_CODE
    rm -r "${PREFIX:?PREFIX is Null}/$1"
    git_add "$1"
    git_commit "Removed note $1"
}

cmd_rename() {
    die_if_invalid_path "$2"
    die_if_name_not_entered "$1"
    die_if_name_not_entered "$2"
    test -e "$PREFIX/$1" || die "Note '$1' doesn\`t exist" $INVALID_ARG_CODE
    test -f "$PREFIX/$2" && die "Note '$2' already exists" $INVALID_ARG_CODE

    _DIRNAME="$(dirname "$2")"

    if [ ! -d "$PREFIX/$_DIRNAME" ]; then
        mkdir "$PREFIX/$_DIRNAME"
    fi

    mv "$PREFIX/$1" "$PREFIX/$2"
    git_add "$1"
    git_add "$2"
    git_commit "Note $1 renamed to $2"
}

cmd_find() {
    die_if_depends_not_installed "find"
    find "$PREFIX" \( -name .git -o -name '.img*' \) -prune -o -iname "$1" -print | _exclude_prefix
    exit 0
}

cmd_grep() {
    grep "$1" "$PREFIX" -rH --color=always --exclude-dir=".git" --exclude-dir=".img"
    exit 0
}

cmd_export() {
    tar -C "$PREFIX" -czf - .
}

cmd_sync() {
    local ff="Fast-forward"
    local merge="Merge"

    local red=$'\e[31m'
    local green=$'\e[32m'
    local nocolor=$'\e[0m'

    output="$(cmd_git pull "$ORIGIN" "$BRANCH" --strategy-option ours --no-rebase --no-edit)"
    echo -e "$output" | sed -e "s/${ff}/${green}${ff}${nocolor}/g" | sed -e "s/${merge}/${red}${merge}${nocolor}/g"

    if echo "$output" | grep "$merge"; then
        if _is_yes "$(_ask_user "[?] Merge detected! Push merge-commit? [N/y]" "y")"; then
            cmd_git push
        fi
    fi
}

_exclude_prefix() {
    sed -e "s#${PREFIX}/\{0,1\}##"
}

_format_and_sort_completions() {
    _exclude_prefix | sed '/^$/d' | sort
}

_find_notes_to_complete() {
    die_if_depends_not_installed "find"
    find "$PREFIX" \( -name .git -o -name '.img*' \) -prune -o $1 -print | _format_and_sort_completions
}

__error_if_storage_not_initialized() {
    if __is_note_storage_initialized; then
        echo -e "$OK_MESSAGE"
    else
        echo -e "$ERROR_MESSAGE"
    fi
}

__error_if_invalid_EDITOR_variable() {
    if _is_variable_set "EDITOR" && _is_EDITOR_valid; then
        echo -e "$OK_MESSAGE"
    else
        echo -e "$ERROR_MESSAGE"
    fi
}

__error_if_depends_not_installed() {
    if _is_depends_installed "$1"; then
        echo -e "$OK_MESSAGE"
    else
        echo -e "$ERROR_MESSAGE"
    fi
}

__warn_if_depends_not_installed() {
    if _is_depends_installed "$1"; then
        echo -e "$OK_MESSAGE"
    else
        echo -e "$WARN_MESSAGE"
    fi
}

cmd_checkhealth() {
    echo -e "Is note storage initialized?... $(__error_if_storage_not_initialized)"

    echo -e "Is variable EDITOR valid?... $(__error_if_invalid_EDITOR_variable)"

    echo -e "Is dependencies installed?..."
    echo -e "\tgit $(__error_if_depends_not_installed git)"

    echo -e "Is optional dependencies installed?..."
    echo -e "\t$FZF $(__warn_if_depends_not_installed $FZF)"
    echo -e "\t$FZF_PAGER $(__warn_if_depends_not_installed $FZF_PAGER)"
    echo -e "\tgrip $(__warn_if_depends_not_installed grip)"
    echo -e "\ttree $(__warn_if_depends_not_installed tree)"
    echo -e "\tfind $(__warn_if_depends_not_installed find)"
    exit 0
}

cmd_complete_notes() {
    _find_notes_to_complete '-type f'
}

cmd_complete_subdirs() {
    _find_notes_to_complete '-type d'
}

cmd_complete_files() {
    _find_notes_to_complete '-type f,d'
}

complete_commands() {
    echo "init:Initialize new note storage in ~/.notes
edit:Creates or edit existing note with \$EDITOR
fedit:Find note by fzf and edit with \$EDITOR
show:Render note in terminal by \$PAGER
render:Render note in browser by grip in localhost:6751
rm:Remove note
mv:Rename note
ls:List notes
export:Export notes in tar.gz format, redirect output in stdout
tree:Show tree of notes
find:Find note by name
grep:Find notes by pattern
mkdir:Creates directory
sync:Pull changes from remote note storage(in case of conflict, accepts yours changes)
git:Proxy commands to git
--prefix:Prints to stdout current notes storage
checkhealth:Check installed dependencies and initialized storage"
}


cmd_complete_bash_commands() {
    local IFS=$'\n'
    local cmd
    for cmd in $(complete_commands)
    do
        echo "$cmd" | cut -f1 -d":"
    done
}

cmd_complete_zsh_commands() {
    complete_commands | tr "\n" ";" | head --bytes -1
}

cmd_get_storage() {
    echo "$PREFIX"
    exit 0
}

cmd_complete() {
    case "$1" in
        edit|show|render) shift;  cmd_complete_notes          "$@" ;;
        tree|mkdir) shift;        cmd_complete_subdirs        "$@" ;;
        mv|rm|ls) shift;          cmd_complete_files          "$@" ;;
        bash) shift;              cmd_complete_bash_commands  "$@" ;;
        zsh) shift;               cmd_complete_zsh_commands   "$@" ;;
    esac
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

if [[ ! -v 1 ]]; then
    die "Type '$PROGRAM help' for usage" 1
fi

case "$1" in
    init) shift;            cmd_init         "$@" ;;
    help|--help|-h) shift;  cmd_usage        "$@" ;;
    version|-V) shift;      cmd_version      "$@" ;;
    checkhealth) shift;     cmd_checkhealth  "$@" ;;
esac


die_if_not_initialized
PREFIX="$(cat "$CONFIGFILE")"


if [[ -n "$(cmd_git status -s)" ]]; then
    echo "$PROGRAM: WARNING: repository not clean!" 1>&2
fi


case "$1" in
    show) shift;      cmd_show         "$@" ;;
    render) shift;    cmd_render       "$@" ;;
    ls) shift;        cmd_ls           "$@" ;;
    tree) shift;      cmd_tree         "$@" ;;
    find) shift;      cmd_find         "$@" ;;
    grep) shift;      cmd_grep         "$@" ;;
    complete) shift;  cmd_complete     "$@" ;;
    --prefix) shift;  cmd_get_storage  "$@" ;;
esac


_die_if_locked
_set_lock
trap _release_lock ERR
trap _release_lock EXIT


case "$1" in
    edit) shift;      cmd_edit    "$@" ;;
    fedit) shift;     cmd_fedit   "$@" ;;
    rm) shift;        cmd_delete  "$@" ;;
    mv) shift;        cmd_rename  "$@" ;;
    mkdir) shift;     cmd_mkdir   "$@" ;;
    export) shift;    cmd_export  "$@" ;;
    sync) shift;      cmd_sync    "$@" ;;
    git) shift;       cmd_git     "$@" ;;

    *)                cmd_usage   "$@" ;;
esac
exit 0
