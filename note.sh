#!/usr/bin/env bash


set -ueo pipefail
shopt -s nullglob

readonly CONFIGFILE="$HOME/.notes-storage-path"
readonly DEFAULT_PREFIX="$HOME/.notes"
readonly LOCKFILE="/tmp/note.lock"

readonly ORIGIN="origin"
readonly BRANCH="master"

readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NOCOLOR='\033[0m'

readonly OK_MESSAGE="${GREEN}OK${NOCOLOR}"
readonly WARN_MESSAGE="${YELLOW}WARN${NOCOLOR}"
readonly ERROR_MESSAGE="${RED}ERROR${NOCOLOR}"


bye() {
    echo "$(basename "$0"): Error: $1" 1>&2
    exit $2
}


cmd_usage() {
    echo "Usage:
    note help
        Show this text
    note init [-p PATH] [-r REMOTE]
        Initialize new note storage in PATH(default=~/.notes), if REMOTE specified, pulls notes from there
    note version
        Print version and exit
    note edit (PATH_TO_NOTE)
        Creates or edit existing note with $EDITOR, after save changes by git
    note show (PATH_TO_NOTE)
        Render note in terminal by glow
    note render (PATH_TO_NOTE)
        Render note in browser by grip in localhost:6751
    note rm (PATH_TO_NOTE)
        Removes note
    note mv (PATH_TO_NOTE) (new-note-name)
        Rename note
    note ls [PATH_TO_NOTE]...
        List notes
    note mkdir (PATH_TO_DIR)
        Creates new directory and subdirs
    note tree [PATH_TO_SUBDIR]
        Show notes in storage or subdir
    note find (NOTE_NAME)
        Find note with name
    note grep (PATTERN)
        Find notes by pattern
    note checkhealth
        Check installed dependencies and initialized storage
    note sync
        Pull changes from remote note storage(in case of conflict, accepts yours changes)
    note git ...
        Proxy commands to git
    note --prefix
        Prints to stdout current notes storage
    note export
        Export notes in tar.gz format, redirect output in stdout (use note export > notes.tar.gz)" >&2
    exit 0
}

cmd_version() {
    echo "Note 1.10.0"
    exit 0
}

_validate_arg(){
	if [[ $2 == -* ]]; then
		bye "Option $1 requires an argument" 2
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
                bye "Option -$OPTARG requires an argument" 2
            ;;
            \?)
                bye "Invalid option: -$OPTARG" 2
            ;;
        esac

    done

    echo "$PREFIX" > "$CONFIGFILE"

    if [ ! -d "$PREFIX" ]; then
        mkdir "$PREFIX"
    fi
    git init -b "$BRANCH" "$PREFIX"
    if [ -n "$remote_storage" ]; then
        git -C "$PREFIX" remote add origin "$remote_storage"
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
}

die_if_not_initialized() {
    if ! __is_note_storage_initialized; then
        bye "You need to initialize: note init [-p PATH]" 2
    fi
}

die_if_name_not_entered() {
    test -n "$1" || bye "Note name wasn\`t entered" 4
}

cmd_git() {
    git -C "$PREFIX" $*
}

git_add() {
    git -C "$PREFIX" add "$1"
}

git_commit() {
    git -C "$PREFIX" commit -m "$1" 1>/dev/null
}

die_if_invalid_path() {
    if [[ "$1" =~ ".." ]]; then
        bye "Path can\`t contains '..'" 3
    fi

    if [[ "$1" = /* ]]; then
        bye "Path can\`t start from '/'" 3
    fi
}

_is_depends_installed() {
    which "$1" &>/dev/null
}

die_if_depends_not_installed() {
    _is_depends_installed "$1" || bye "'$1' not installed. Use 'note checkhealth'."
}

cmd_edit() {
    die_if_name_not_entered "$1"
    die_if_invalid_path "$1"


    test -d "$PREFIX/$1" && bye "Can\`t edit directory '$1'" 2

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

cmd_list() {
    die_if_invalid_path "$*"
    cd "$PREFIX"
    ls --color=always $*
}

cmd_show() {
    die_if_invalid_path "$1"
    die_if_name_not_entered "$1"
    die_if_depends_not_installed "glow"
    test -f "$PREFIX/$1" || bye "Note '$1' doesn\`t exist" 1
    ${CAT:-glow -p} "$PREFIX/$1"
    exit 0
}

cmd_ls() {
    die_if_invalid_path "$*"
    if [ -z "$*" ]; then
        cmd_list
    else
        cmd_list $*
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

    test -d "$PREFIX/$path" || bye "'$path' not a directory" 1
    cd "$PREFIX"

    tree -N -C --noreport "$path"
    exit 0
}

cmd_render() {
    die_if_name_not_entered "$1"
    die_if_depends_not_installed "grip"

    test -f "$PREFIX/$1" || bye "Note '$1' doesn\`t exist" 1
    echo "http://localhost:6751 in browser"
    grip -b "$PREFIX/$1" localhost:6751 1>/dev/null 2>/dev/null
    exit 0
}

cmd_delete() {
    die_if_invalid_path "$1"
    die_if_name_not_entered "$1"
    test -e "$PREFIX/$1" || bye "Note '$1' doesn\`t exist" 1
    rm -r "${PREFIX:?PREFIX is Null}/$1"
    git_add "$1"
    git_commit "Removed note $1"
}

cmd_rename() {
    die_if_invalid_path "$2"
    die_if_name_not_entered "$1"
    die_if_name_not_entered "$2"
    test -e "$PREFIX/$1" || bye "Note '$1' doesn\`t exist" 1
    test -f "$PREFIX/$2" && bye "Note '$2' already exists" 2

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
    find "$PREFIX" \( -name .git -o -name .img \) -prune -o -iname "$1" -print | _exclude_prefix
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
    cmd_git pull "$ORIGIN" "$BRANCH" --strategy-option ours --no-rebase --no-edit
}

_exclude_prefix() {
    sed -e "s#${PREFIX}/\{0,1\}##"
}

_format_and_sort_completions() {
    _exclude_prefix | sed '/^$/d' | sort
}

_find_notes_to_complete() {
    find "$PREFIX" \( -name .git -o -name .img \) -prune -o $1 -print | _format_and_sort_completions
}

__error_if_storage_not_initialized() {
    if __is_note_storage_initialized; then
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

    echo -e "Is dependencies installed?..."
    echo -e "\tgit $(__error_if_depends_not_installed git)"

    echo -e "Is optional dependencies installed?..."
    echo -e "\tglow $(__warn_if_depends_not_installed glow)"
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
edit:Creates or edit existing note with $EDITOR
show:Render note in terminal by glow
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

_release_lock() {
    rm "$LOCKFILE"
}


case "$1" in
    init) shift;         cmd_init         "$@" ;;
    help|--help) shift;  cmd_usage        "$@" ;;
    version|-V) shift;   cmd_version      "$@" ;;
    checkhealth) shift;  cmd_checkhealth  "$@" ;;
esac


die_if_not_initialized
PREFIX="$(cat "$CONFIGFILE")"


case "$1" in
    show) shift;      cmd_show     "$@" ;;
    render) shift;    cmd_render   "$@" ;;
    ls) shift;        cmd_ls       "$@" ;;
    tree) shift;      cmd_tree     "$@" ;;
    find) shift;      cmd_find     "$@" ;;
    grep) shift;      cmd_grep     "$@" ;;
    complete) shift;  cmd_complete "$@" ;;
    --prefix) shift;  cmd_get_storage  "$@" ;;
esac


if [ -e "$LOCKFILE" ]; then
    bye "Seems another process is running. If not, just delete /tmp/note.lock" 6
fi
touch "$LOCKFILE"

trap _release_lock ERR
trap _release_lock EXIT


case "$1" in
    edit) shift;      cmd_edit     "$@" ;;
    rm) shift;        cmd_delete   "$@" ;;
    mv) shift;        cmd_rename   "$@" ;;
    mkdir) shift;     cmd_mkdir    "$@" ;;
    export) shift;    cmd_export   "$@" ;;
    sync) shift;      cmd_sync     "$@" ;;
    git) shift;       cmd_git      "$@" ;;

    *)                cmd_usage    "$@" ;;
esac
exit 0
