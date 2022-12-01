#!/usr/bin/env bash


PREFIX="$HOME/.notes"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NOCOLOR='\033[0m'

OK_MESSAGE="${GREEN}OK${NOCOLOR}"
WARN_MESSAGE="${YELLOW}WARN${NOCOLOR}"
ERROR_MESSAGE="${RED}ERROR${NOCOLOR}"


bye() {
    echo "$(basename "$0"): Error: $1" 1>&2
    exit $2
}


cmd_usage() {
    echo 'Usage:
    note help
        Show this text
    note init
        Initialize new note storage
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
    note tree [PATH_TO_SUBDIR]
        Show notes in storage or subdir
    note find (NOTE_NAME)
        Find note with name
    note grep (PATTERN)
        Find notes by pattern
    note checkhealth
        Check installed dependencies and initialized storage
    note export
        Export notes in tar.gz format, redirect output in stdout (use note export > notes.tar.gz)' >&2
    exit 1
}

cmd_version() {
    echo "Note 1.6.0"
}

cmd_init() {
    test -e "$PREFIX" || \
    mkdir "$PREFIX"
    git init "$PREFIX"
}

die_if_name_not_entered() {
    test -n "$1" || bye "Note name wasn\`t entered" 4
}

git_add() {
    git -C "$PREFIX" add "$PREFIX/$1"
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

    if [ -e "$PREFIX/$1" ]; then
        last_modified_time="$(stat -c '%Y' "$PREFIX/$1")"
    else
        echo "Creating new note '$1'"
        last_modified_time=0
    fi

    _new_dir_flag=""

    _DIRNAME="$(dirname "$1")"

    if [ ! -d "$PREFIX/$_DIRNAME" ]; then
        mkdir "$PREFIX/$_DIRNAME"
        _new_dir_flag="true"
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
        if [ -n "$_new_dir_flag" ]; then
            rm -r "$PREFIX/$_DIRNAME"
        fi
    fi
}

cmd_list() {
    die_if_invalid_path "$*"
    cd $PREFIX
    ls --color=always $*
}

cmd_show() {
    die_if_invalid_path "$1"
    die_if_name_not_entered "$1"
    die_if_depends_not_installed "glow"
    test -f "$PREFIX/$1" || bye "Note '$1' doesn\`t exist" 1
    glow -p "$PREFIX/$1"
}

cmd_ls() {
    if [ -z "$*" ]; then
        cmd_list
    else
        cmd_list $*
    fi
}

cmd_tree() {
    die_if_invalid_path "$1"
    die_if_depends_not_installed "tree"

    test -d "$PREFIX/$1" || bye "'$1' not a directory" 1
    cd $PREFIX

    if [ -z "$1" ]; then
        echo "Notes"
    else
        echo "$1"
    fi
    tree -N -C --noreport $1 | tail -n +2
}

cmd_render() {
    die_if_name_not_entered "$1"
    die_if_depends_not_installed "grip"

    test -f "$PREFIX/$1" || bye "Note '$1' doesn\`t exist" 1
    echo "http://localhost:6751 in browser"
    grip -b "$PREFIX/$1" localhost:6751 1>/dev/null 2>/dev/null
}

cmd_delete() {
    die_if_invalid_path "$1"
    die_if_name_not_entered "$1"
    test -e "$PREFIX/$1" || bye "Note '$1' doesn\`t exist" 1
    rm -r "$PREFIX/$1"
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
    find "$PREFIX" -iname "$1" | _exclude_prefix
}

cmd_grep() {
    grep "$1" "$PREFIX" -rH --color=always --exclude-dir=".git" --exclude-dir=".img"
}

cmd_export() {
    tar -C "$PREFIX" -czf - .
}

_exclude_prefix() {
    sed -e "s#${PREFIX}/\{0,1\}##"
    # "
}

_format_and_sort_completions() {
    _exclude_prefix | sed '/^$/d' | sort
}

_find_notes_to_complete() {
    find "$PREFIX" \( -name .git -o -name .img \) -prune -o $1 -print | _format_and_sort_completions
}

__is_note_storage_initialized() {
    if [ -w "$PREFIX" ] && [ -w "$PREFIX/.git" ]; then
        echo -e "$OK_MESSAGE"
    else
        echo -e "$WARN_MESSAGE"
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
    echo -e "Is note storage initialized?... $(__is_note_storage_initialized)"

    echo -e "Is dependencies installed?..."
    echo -e "\tgit $(__error_if_depends_not_installed git)"

    echo -e "Is optional dependencies installed?..."
    echo -e "\tglow $(__warn_if_depends_not_installed glow)"
    echo -e "\tgrip $(__warn_if_depends_not_installed grip)"
    echo -e "\ttree $(__warn_if_depends_not_installed tree)"
    echo -e "\tfind $(__warn_if_depends_not_installed find)"
}

cmd_complete_notes() {
    _find_notes_to_complete '-type f'
}

cmd_complete_subdirs() {
    _find_notes_to_complete '-type d'
}

cmd_complete_files() {
    _find_notes_to_complete
}

complete_commands() {
    echo 'init:Initialize new note storage in ~/.notes
edit:Creates or edit existing note with $EDITOR
show:Render note in terminal by glow
render:Render note in browser by grip in localhost:6751
rm:Remove note
mv:Rename note
ls:List notes
export:Export notes in tar.gz format, redirect output in stdout
tree:Show tree of notes
find:Find note by name
grep:Find notes by pattern
checkhealth:Check installed dependencies and initialized storage'
}


cmd_complete_bash_commands() {
    for __command in $(complete_commands)
    do
            echo $__command | tr ":" '\n' | head -n 1
    done
}

cmd_complete_zsh_commands() {
    echo "$(complete_commands)" | tr "\n" ";" | head --bytes -1
}


cmd_complete() {
    case "$1" in
        edit|show|render) shift;    cmd_complete_notes "$@" ;;
        tree) shift;                cmd_complete_subdirs "$@" ;;
        mv|rm|ls) shift;            cmd_complete_files "$@" ;;
        bash_commands) shift; cmd_complete_bash_commands "$@" ;;
        zsh_commands) shift;  cmd_complete_zsh_commands "$@" ;;
    esac
}

case "$1" in
    init) shift;               cmd_init    "$@" ;;
    help|--help) shift;        cmd_usage   "$@" ;;
    show) shift;               cmd_show    "$@" ;;
    render) shift;             cmd_render    "$@" ;;
    edit) shift;               cmd_edit  "$@" ;;
    rm) shift;                 cmd_delete  "$@" ;;
    mv) shift;                 cmd_rename  "$@" ;;
    ls) shift;                 cmd_ls  "$@" ;;
    tree) shift;               cmd_tree  "$@" ;;
    find) shift;               cmd_find  "$@" ;;
    grep) shift;               cmd_grep  "$@" ;;
    export) shift;             cmd_export  "$@" ;;
    version|-V) shift;         cmd_version  "$@" ;;
    complete) shift;           cmd_complete  "$@" ;;
    checkhealth) shift;        cmd_checkhealth  "$@" ;;

    *)                         cmd_usage    "$@" ;;
esac
exit 0
