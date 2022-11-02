#!/usr/bin/env bash


PREFIX="$HOME/.notes"

bye() {
    echo "$(basename "$0"): Error: $1" 1>&2
    exit $2
}


cmd_usage() {
    echo 'Usage:
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
    note help
        Show this text
    note ls [PATH_TO_NOTE]...
        List notes
    note tree [PATH_TO_SUBDIR]
        Show notes in storage or subdir
    note export
        Export notes in tar.gz format, redirect output in stdout (use note export > notes.tar.gz)' >&2
    exit 1
}

cmd_version() {
    echo "Note 1.4.5"
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

cmd_export() {
    tar -C "$PREFIX" -czf - .
}

_format_and_sort_completions() {
    sed -e "s#${PREFIX}/\{0,1\}##" | sed '/^$/d' | sort
    # "
}

_find_notes_to_complete() {
    find "$PREFIX" -type d \( -name .git -o -name .img \) -prune -o $1 -print | _format_and_sort_completions
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

cmd_complete_commands() {
    echo 'init:Initialize new note storage in ~/.notes;edit:Creates or edit existing note with $EDITOR;show:Render note in terminal by glow;render:Render note in browser by grip in localhost:6751;rm:Remove note;mv:Rename note;ls:List notes;export:Export notes in tar.gz format, redirect output in stdout;tree:Show tree of notes'
}

cmd_complete() {
    case "$1" in
        notes) shift;    cmd_complete_notes "$@" ;;
        subdirs) shift;  cmd_complete_subdirs "$@" ;;
        files) shift;    cmd_complete_files "$@" ;;
        commands) shift; cmd_complete_commands "$@" ;;
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
    export) shift;             cmd_export  "$@" ;;
    version) shift;            cmd_version  "$@" ;;
    complete) shift;           cmd_complete  "$@" ;;

    *)                         cmd_usage    "$@" ;;
esac
exit 0
