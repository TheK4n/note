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
    note edit (NOTE)
        Creates or edit existing note with $EDITOR, after save changes by git
    note show (NOTE)
        Render note in terminal by glow
    note render (NOTE)
        Render note in browser by grip in localhost:6751
    note rm (NOTE)
        Removes note
    note mv (NOTE) (new-note-name)
        Rename note
    note help
        Show this text
    note ls [NOTE]...
        List notes
    note export
        Export notes in tar.gz format, redirect output in stdout (use note export > notes.tar.gz)'
}

cmd_init() {
    test -e "$PREFIX" || \
    mkdir "$PREFIX"
    git init "$PREFIX"
}

die_if_name_not_entered() {
    test -n "$1" || bye "Note name wasn\`t entered"
}

git_add() {
    git -C "$PREFIX" add "$PREFIX/$1"
}

git_commit() {
    git -C "$PREFIX" commit -m "$1" 1>/dev/null
}

cmd_edit() {
    die_if_name_not_entered $1

    if [ -e "$PREFIX/$1" ]; then
        last_modified_time="$(stat -c '%Y' "$PREFIX/$1")"
    else
        echo "Creating new note '$1'"
        last_modified_time=0
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
    fi
}

cmd_list() {
    cd $PREFIX
    ls $*
}

cmd_show() {
    die_if_name_not_entered $1
    test -e "$PREFIX/$1" || bye "Note '$1' doesn\`t exist"
    glow -p "$PREFIX/$1"
}

cmd_ls() {
    if [ -z "$*" ]; then
        cmd_list
    else
        cmd_list $*
    fi
}

cmd_render() {
    die_if_name_not_entered $1
    test -e "$PREFIX/$1" || bye "Note '$1' doesn\`t exist"
    echo "http://localhost:6751 in browser"
    grip -b "$PREFIX/$1" localhost:6751 1>/dev/null 2>/dev/null
}

cmd_delete() {
    die_if_name_not_entered $1
    test -e "$PREFIX/$1" || bye "Note '$1' doesn\`t exist"
    rm "$PREFIX/$1"
    git_add "$1"
    git_commit "Removed note $1"
}

cmd_rename() {
    die_if_name_not_entered $1
    test -e "$PREFIX/$1" || bye "Note '$1' doesn\`t exist"
    test -n "$1" || bye "New note name wasn\`t entered"
    test -e "$PREFIX/$2" && bye "Note '$2' already exists"
    mv "$PREFIX/$1" "$PREFIX/$2"
    git_add "$1"
    git_add "$2"
    git_commit "Note $1 renamed to $2"
}

cmd_export() {
    tar -C "$PREFIX" -czf - .
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
    export) shift;             cmd_export  "$@" ;;

    *)                         cmd_usage    "$@" ;;
esac
exit 0
