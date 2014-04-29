# pkg.bash
#
# Ellipsis package interface. Encapsulates various useful functions for working
# with packages.

load fs
load hooks
load log
load path
load utils

# List of hooks available to package authors.
PKG_HOOKS=(install uninstall unlink symlinks pull push status list)

# Convert package name to path.
pkg.path_from_name() {
    echo "$ELLIPSIS_PATH/packages/$1"
}

# Convert package path to name, stripping any leading dots.
pkg.name_from_path() {
    echo ${1##*/} | sed -e "s/^\.//"
}

# Set PKG_NAME, PKG_PATH. If $1 looks like a path it's assumed to be
# PKG_PATH and not PKG_NAME, otherwise assume PKG_NAME.
pkg.init_globals() {
    if path.is_path "$1"; then
        PKG_PATH="$1"
        PKG_NAME="$(pkg.name_from_path $PKG_PATH)"
    else
        PKG_NAME="$1"
        PKG_PATH="$(pkg.path_from_name $PKG_NAME)"
    fi
}

# Initialize a package and it's hooks.
pkg.init() {
    pkg.init_globals ${1:-$PKG_PATH}

    # Exit if we're asked to operate on an unknown package.
    if [ ! -d "$PKG_PATH" ]; then
        log.error "Unkown package $PKG_NAME, $(path.relative_path $PKG_PATH) missing!"
        exit 1
    fi

    # Source ellipsis.sh if it exists to initialize package's hooks.
    if [ -f "$PKG_PATH/ellipsis.sh" ]; then
        source "$PKG_PATH/ellipsis.sh"
    fi
}

# List symlinks associated with package.
pkg.list_symlinks() {
    for file in $(fs.list_symlinks); do
        if [[ "$(readlink $file)" == *packages/$PKG_NAME* ]]; then
            echo $file
        fi
    done
}

# Print file -> symlink mapping
pkg.list_symlink_mappings() {
    for file in $(fs.list_symlinks); do
        local link=$(readlink $file)

        if [[ "$link" == *packages/$PKG_NAME* ]]; then
            echo "$(path.relative_packages_path $link) -> $(path.relative_path $file)";
        fi
    done
}

# Run command inside PKG_PATH.
pkg.run() {
    local cwd="$(pwd)"

    # change to package dir
    cd "$PKG_PATH"

    # run command
    $@

    # return after running command
    cd "$cwd"
}

# run hook if it's defined, otherwise use default implementation
pkg.run_hook() {
    if ! utils.cmd_exists hooks.$1; then
        log.error "Unknown hook!"
        exit 1
    fi

    # Run packages's hook.
    if utils.cmd_exists pkg.$1; then
        pkg.run pkg.$1
    else
        pkg.run hooks.$1
    fi
}

# Clear globals, hooks.
pkg.del() {
    pkg._unset_vars
    pkg._unset_hooks
}

# Unset global packages.
pkg._unset_vars() {
    unset PKG_NAME
    unset PKG_PATH
}

# Unset any hooks that might have been defined by package.
pkg._unset_hooks() {
    for hook in ${PKG_HOOKS[@]}; do
        unset -f pkg.$hook
    done
}