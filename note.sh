PREFIX="$HOME/.notes"

bye() {
    echo "$(basename "$0"): Error: $1" 1>&2
    exit $2
}

cmd_usage() {
    echo 'Usage:
    tip init
        Initialize new tip storage
    tip ls
        List tips
    tip help
        Show this text
    tip edit (tip-name)
        Creates or edit existing tip with $EDITOR, after save changes by git
    tip show (tip-name)
        Render tip in terminal by glow
    tip render (tip-name)
        Render tip in browser by grip in localhost:6751
    tip rm (tip-name)
        Removes tip
    tip mv (tip-name) (new-tip-name)
        Rename tip'
}

cmd_init() {
    test -e "$PREFIX" || \
    mkdir "$PREFIX"
    git init "$PREFIX"
}

git_add_commit() {
    git -C "$PREFIX" add "$1"
    git_commit "$2"
}

git_commit() {
    git -C "$PREFIX" commit -m "$1"
}

cmd_edit() {
    last_modified_time="$(stat -c '%Y' "$PREFIX/$1")"
    test -n "$1" || bye "No tip name provided"
    $EDITOR "$PREFIX/$1"

    if [ "$last_modified_time" != "$(stat -c '%Y' "$PREFIX/$1")" ]; then
        git_add_commit "$PREFIX/$1" "Edited tip $1"
        echo "Edited tip "$PREFIX/$1""
    fi
}

cmd_list() {
    ls "$PREFIX"
}

cmd_show() {
    test -n "$1" || bye "No tip name provided"
    test -e "$PREFIX/$1" || bye "No tip in $PREFIX"
    glow -p "$PREFIX/$1"
}

cmd_render() {
    test -n "$1" || bye "No tip name provided"
    test -e "$PREFIX/$1" || bye "No tip in $PREFIX"
    echo "http://localhost:6751 in browser"
    grip -b "$PREFIX/$1" localhost:6751 1>/dev/null 2>/dev/null
}

cmd_delete() {
    test -n "$1" || bye "No tip name provided"
    test -e "$PREFIX/$1" || bye "No tip in $PREFIX"
    rm "$PREFIX/$1"
    git_add_commit "$PREFIX/$1" "Removed tip $1"
}

case "$1" in
    init) shift;               cmd_init    "$@" ;;
    help|--help) shift;        cmd_usage   "$@" ;;
    show) shift;               cmd_show    "$@" ;;
    render) shift;             cmd_render    "$@" ;;
    ls) shift;                 cmd_list  "$@" ;;
    edit) shift;               cmd_edit  "$@" ;;
    rm) shift;                 cmd_delete  "$@" ;;

    *)                         cmd_list    "$@" ;;
esac
exit 0
