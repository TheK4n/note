PREFIX="$HOME/.tips"

bye() {
    echo "$(basename "$0"): Error: $1" 1>&2
    exit $2
}

cmd_init() {
    test -e "$PREFIX" || \
    mkdir "$PREFIX"
    git init "$PREFIX"
}

git_add() {
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
        git_add "$PREFIX/$1" "Edited tip $1"
        echo "Edited tip "$PREFIX/$1""
    fi
}

cmd_list() {
    ls "$PREFIX"
}

cmd_show() {
    test -n "$1" || bye "No tip name provided"
    test -e "$PREFIX/$1" || bye "No tip in $PREFIX"
    echo "http://localhost:6751 in browser"
    grip -b "$PREFIX/$1" localhost:6751 1>/dev/null 2>/dev/null
}

cmd_delete() {
    test -n "$1" || bye "No tip name provided"
    test -e "$PREFIX/$1" || bye "No tip in $PREFIX"
    rm "$PREFIX/$1"
    git_add "$PREFIX/$1" "Removed tip $1"
}

case "$1" in
    init) shift;               cmd_init    "$@" ;;
    help|--help) shift;        cmd_usage   "$@" ;;
    show) shift;               cmd_show    "$@" ;;
    ls) shift;                 cmd_list  "$@" ;;
    edit) shift;               cmd_edit  "$@" ;;
    sync) shift;               cmd_rsync_all   "$@" ;;
    delete|rm|remove) shift;   cmd_delete  "$@" ;;

    *)                         cmd_list    "$@" ;;
esac
exit 0
