#!/usr/bin/env bash
# Copyright © 2022-2024 Kan Vladislav <thek4n@yandex.ru>. All rights reserved.


set -ueo pipefail
shopt -s nullglob

: "${XDG_DATA_HOME:=$HOME/.local/share}"
readonly CONFIGFILE="$XDG_DATA_HOME/note/notes-storage-path"

readonly DEFAULT_PREFIX="$HOME/.notes"

readonly RUNTIME_DIR="$HOME/.local/state"
readonly LOCKFILE="$RUNTIME_DIR/note/lock"
readonly LAST_EDIT_NOTE="$RUNTIME_DIR/note/last"

readonly ORIGIN="origin"
readonly BRANCH="master"

declare PROGRAM
PROGRAM="$(basename "$0")"
readonly PROGRAM

readonly FZF="fzf"
readonly FZF_PAGER="bat"
readonly RG="rg"

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
    $PROGRAM edit|e (PATH_TO_NOTE)
        Creates or edit existing note with \$VISUAL, after save changes by git
    $PROGRAM today
        Creates or edit note with name like daily/06-01-24.md
    $PROGRAM last
        Edit last opened note
    $PROGRAM fedit|fe
        Find note by fzf and edit with \$VISUAL
    $PROGRAM fgrep|fg
        Find note by content with fzf and edit with \$VISUAL
    $PROGRAM show|cat (PATH_TO_NOTE)
        Show note in terminal by \$NOTEPAGER if defined, otherwice \$PAGER
    $PROGRAM rm (PATH_TO_NOTE)
        Removes note
    $PROGRAM mv (PATH_TO_NOTE) (new-note-name)
        Rename note
    $PROGRAM ln (PATH_TO_NOTE) (link-name)
        Create symbolic link
    $PROGRAM ls|list [PATH_TO_NOTE]...
        List notes
    $PROGRAM mkdir (PATH_TO_DIR)
        Creates new directory and subdirs
    $PROGRAM tree [PATH_TO_SUBDIR]
        Show notes in storage or subdir
    $PROGRAM find (NOTE_NAME)
        Find note with name
    $PROGRAM grep (PATTERN)
        Find notes by pattern
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

_is_first_command_in_variable_are_program() {
    command -v "${1%% *}" &>/dev/null
}

cmd_edit() {
    if ! _is_variable_set "VISUAL" || ! _is_first_command_in_variable_are_program "$VISUAL"; then
        if ! _is_variable_set "EDITOR" || ! _is_first_command_in_variable_are_program "$EDITOR"; then
            die "EDITOR ($EDITOR) is invalid" $INVALID_STATE_CODE
        fi
        VISUAL="$EDITOR"
    fi


    die_if_name_not_entered "$1"
    die_if_invalid_path "$1"

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

    echo "$1" > "$LAST_EDIT_NOTE"
    $VISUAL "$PREFIX/$1"

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

cmd_last() {
    if [ ! -e "$LAST_EDIT_NOTE" ] || [ -z "$(cat "$LAST_EDIT_NOTE")"  ]; then
        die "No last note" $INVALID_STATE_CODE
    fi
    cmd_edit "$(cat "$LAST_EDIT_NOTE")"
}

cmd_fedit() {
    die_if_depends_not_installed "$FZF"
    die_if_depends_not_installed "$FZF_PAGER"

    INITIAL_QUERY="${1:-}"

    export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:-} \
        --no-multi \
        --no-sort \
        --preview-window right:60% \
        --preview=\"$FZF_PAGER --plain --wrap=never --color=always $PREFIX/{}\""

    cmd_edit "$(cmd_complete_notes | $FZF --query "$INITIAL_QUERY")"
}

cmd_fg() {
    die_if_depends_not_installed "$FZF"
    die_if_depends_not_installed "$FZF_PAGER"
    die_if_depends_not_installed "$RG"

    INITIAL_QUERY="${1:-}"

    export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:-} \
        --no-multi \
        --no-sort \
        --preview-window right:40% \
        --preview=\"rgout={}; \
        lineno=\$(echo \$rgout | awk -F: '{print \$2}'); \
        $FZF_PAGER --plain --wrap=never --color=always \
        -H \$lineno \
        -r \$lineno:-\$((FZF_PREVIEW_LINES/2)) \
        -r \$lineno:+\$FZF_PREVIEW_LINES \
        $PREFIX/\${rgout%%:*}\""

    RG_PREFIX="$RG --column --line-number --no-heading --color=always --smart-case"
    local choosed_note
    choosed_note="$(FZF_DEFAULT_COMMAND="$RG_PREFIX '$INITIAL_QUERY'" \
           $FZF --bind "change:reload:$RG_PREFIX {q} || true" \
           --ansi --disabled --query "$INITIAL_QUERY")"

    cmd_edit "${choosed_note%%:*}"
}

cmd_list() {
    die_if_invalid_path "$*"
    cd "$PREFIX"
    ls --color=always "$@"
}

cmd_show() {
    die_if_invalid_path "$1"
    die_if_name_not_entered "$1"


    if ! _is_variable_set "NOTEPAGER" || ! _is_first_command_in_variable_are_program "$NOTEPAGER"; then
        if ! _is_variable_set "PAGER" || ! _is_first_command_in_variable_are_program "$PAGER"; then
            die "PAGER ($PAGER) is invalid" $INVALID_STATE_CODE
        fi
        NOTEPAGER="$PAGER"
    fi

    test -e "$PREFIX/$1" || die "Note '$1' doesn\`t exist" $INVALID_ARG_CODE

    $NOTEPAGER "$PREFIX/$1"

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

cmd_delete() {
    die_if_invalid_path "$1"
    die_if_name_not_entered "$1"
    test -e "$PREFIX/$1" || die "Note '$1' doesn\`t exist" $INVALID_ARG_CODE
    cmd_git rm -r "$1"
    git_commit "Removed note $1"
}

cmd_rename() {
    die_if_invalid_path "$1"
    die_if_invalid_path "$2"
    die_if_name_not_entered "$1"
    die_if_name_not_entered "$2"
    test -e "$PREFIX/$1" || die "Note or directory '$1' doesn\`t exist" $INVALID_ARG_CODE
    test -f "$PREFIX/$2" && die "Note or directory '$2' already exists" $INVALID_ARG_CODE

    _DIRNAME="$(dirname "$2")"

    if [ ! -d "$PREFIX/$_DIRNAME" ]; then
        mkdir "$PREFIX/$_DIRNAME"
    fi

    mv "$PREFIX/$1" "$PREFIX/$2"
    git_add "$1"
    git_add "$2"
    git_commit "Note $1 renamed to $2"
}

cmd_ln() {
    die_if_invalid_path "$1"
    die_if_invalid_path "$2"
    die_if_name_not_entered "$1"
    die_if_name_not_entered "$2"

    test -e "$PREFIX/$1" || die "Note or directory '$1' doesn\`t exist" $INVALID_ARG_CODE
    test -f "$PREFIX/$2" && die "Note or directory '$2' already exists" $INVALID_ARG_CODE

    ln -s "$PREFIX/$1" "$PREFIX/$2"
    git_add "$2"
    git_commit "Created symlink $2 to note $1"
}

cmd_find() {
    die_if_depends_not_installed "find"
    find "$PREFIX" \( -name .git -o -name '.img*' \) -prune -o -iname "$1" -print | _exclude_prefix
    exit 0
}

cmd_grep() {
    grep "$1" "$PREFIX" -rH --color=always --exclude-dir=".git" --exclude-dir=".img" | _exclude_prefix
    exit 0
}

cmd_export() {
    tar -C "$PREFIX" -czf - .
}

_highlight_text() {
    local nocolor=$'\e[0m'
    sed -e "s/${1}/${2}${1}${nocolor}/g"
}

cmd_sync() {
    local ff="Fast-forward"
    local merge="Merge"

    local red=$'\e[31m'
    local green=$'\e[32m'

    output="$(cmd_git pull "$ORIGIN" "$BRANCH" --strategy-option ours --no-rebase --no-edit)"
    echo -e "$output" | \
        _highlight_text "$ff" "$green" | \
        _highlight_text "$merge" "$red"

    if echo "$output" | grep "$merge" 1>/dev/null; then
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

__error_if_invalid_VISUAL_variable() {
    if _is_variable_set "VISUAL" && _is_depends_installed "$VISUAL"; then
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

    echo -e "Is variable VISUAL valid?... $(__error_if_invalid_VISUAL_variable)"

    echo -e "Is dependencies installed?..."
    echo -e "\tgit $(__error_if_depends_not_installed git)"

    echo -e "Is optional dependencies installed?..."
    echo -e "\t$FZF $(__warn_if_depends_not_installed $FZF)"
    echo -e "\t$FZF_PAGER $(__warn_if_depends_not_installed $FZF_PAGER)"
    echo -e "\t$RG $(__warn_if_depends_not_installed $RG)"
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
edit:Creates or edit existing note with \$VISUAL
e:Creates or edit existing note with \$VISUAL (alias)
today:Creates or edit note with name like daily/06-01-24.md
last:edit last opened note
fedit:Find note by fzf and edit with \$VISUAL
fe:Find note by fzf and edit with \$VISUAL (alias)
fgrep:Find note by content with fzf and edit with \$VISUAL
fg:Find note by content with fzf and edit with \$VISUAL (alias)
show:Render note in terminal by \$NOTEPAGER if defined, otherwice \$PAGER
cat:Render note in terminal by \$PAGER (alias)
rm:Remove note
mv:Rename note
ln:Create symbolic link
list:List notes
ls:List notes (alias)
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
        edit|e|fe|show|cat) shift;  cmd_complete_notes          "$@" ;;
        tree|mkdir) shift;          cmd_complete_subdirs        "$@" ;;
        mv|rm|ls|list) shift;       cmd_complete_files          "$@" ;;
        bash) shift;                cmd_complete_bash_commands  "$@" ;;
        zsh) shift;                 cmd_complete_zsh_commands   "$@" ;;
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
cd "$PREFIX"

if _is_repository_not_clean; then
    echo "$PROGRAM: WARNING: repository not clean!" 1>&2
fi


case "$1" in
    show|cat) shift;  cmd_show         "$@" ;;
    list|ls) shift;   cmd_ls           "$@" ;;
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
    edit|e) shift;    cmd_edit    "$@" ;;
    today) shift;     cmd_today   "$@" ;;
    fedit|fe) shift;  cmd_fedit   "$@" ;;
    fgrep|fg) shift;  cmd_fg      "$@" ;;
    last) shift;      cmd_last    "$@" ;;
    rm) shift;        cmd_delete  "$@" ;;
    mv) shift;        cmd_rename  "$@" ;;
    ln) shift;        cmd_ln      "$@" ;;
    mkdir) shift;     cmd_mkdir   "$@" ;;
    export) shift;    cmd_export  "$@" ;;
    sync) shift;      cmd_sync    "$@" ;;
    git) shift;       cmd_git     "$@" ;;

    *)                cmd_usage 1 "$@" ;;
esac
exit 0