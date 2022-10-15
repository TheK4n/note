PREFIX="$HOME/.notes"

bye() {
    echo "$(basename "$0"): Error: $1" 1>&2
    exit $2
}

cmd_usage() {
    echo 'Usage:
    note init
        Initialize new note storage
    note edit (note-name)
        Creates or edit existing note with $EDITOR, after save changes by git
    note show (note-name)
        Render note in terminal by glow
    note render (note-name)
        Render note in browser by grip in localhost:6751
    note rm (note-name)
        Removes note
    note mv (note-name) (new-note-name)
        Rename note
    note help
        Show this text'
}

cmd_init() {
    test -e "$PREFIX" || \
    mkdir "$PREFIX"
    git init "$PREFIX"
}

git_add() {
    git -C "$PREFIX" add "$PREFIX/$1"
}

git_commit() {
    git -C "$PREFIX" commit -m "$1"
}

cmd_edit() {
    last_modified_time="$(stat -c '%Y' "$PREFIX/$1")"
    test -n "$1" || bye "No note name provided"
    $EDITOR "$PREFIX/$1"

    if [ "$last_modified_time" != "$(stat -c '%Y' "$PREFIX/$1")" ]; then
        git_add "$1"
        git_commit "Edited note $1"
        echo "Edited note "$PREFIX/$1""
    fi
}

cmd_list() {
    ls "$PREFIX"
}

cmd_show() {
    test -n "$1" || bye "No note name provided"
    test -e "$PREFIX/$1" || bye "No note in $PREFIX"
    glow -p "$PREFIX/$1"
}

cmd_render() {
    test -n "$1" || bye "No note name provided"
    test -e "$PREFIX/$1" || bye "No note in $PREFIX"
    echo "http://localhost:6751 in browser"
    grip -b "$PREFIX/$1" localhost:6751 1>/dev/null 2>/dev/null
}

cmd_delete() {
    test -n "$1" || bye "No note name provided"
    test -e "$PREFIX/$1" || bye "No note in $PREFIX"
    rm "$PREFIX/$1"
    git_add "$1"
    git_commit "Removed note $1"
}

cmd_rename() {
    test -n "$1" || bye "No note name provided"
    test -e "$PREFIX/$1" || bye "No note in $PREFIX"
    test -n "$2" || bye "No new note name provided"
    test -e "$PREFIX/$2" && bye "Note $2 already exists"
    mv "$PREFIX/$1" "$PREFIX/$2"
    git_add "$1"
    git_add "$2"
    git_commit "Note $1 renamed to $2"
}

case "$1" in
    init) shift;               cmd_init    "$@" ;;
    help|--help) shift;        cmd_usage   "$@" ;;
    show) shift;               cmd_show    "$@" ;;
    render) shift;             cmd_render    "$@" ;;
    edit) shift;               cmd_edit  "$@" ;;
    rm) shift;                 cmd_delete  "$@" ;;
    mv) shift;                 cmd_rename  "$@" ;;

    *)                         cmd_list    "$@" ;;
esac
exit 0
