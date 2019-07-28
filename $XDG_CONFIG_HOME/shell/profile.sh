# shell/profile.sh - session for POSIX shells
# Detect OS -------------------------------------------------------------------
export OS="$(uname -s)"
if [ "Linux" = "$OS" ]; then
    if [ -f /etc/lsb-release -o -d /etc/lsb-release.d ]; then
        export DISTRO="$(lsb_release -i | cut -d: -f2 | sed s/'^\t'//)"
        export DISTROVER="$(lsb_release -sr 2>/dev/null)"
    else
        export DISTRO="$(ls -d /etc/[A-Za-z]*[_-][rv]e[lr]* \
            | grep -v "lsb" | sed 1q \
            | cut -d'/' -f3 | cut -d'-' -f1 | cut -d'_' -f1)"
    fi
fi

# ENVIRONMENT -----------------------------------------------------------------
#XDG vars are the scaffold for the other ones, and quite important.
#Set them to their default values here
set -a
if [ "$OS" = Darwin ]; then
    XDG_CONFIG_HOME="${XDG_CONFIG_HOME-$HOME/Library/Application Support}"
    XDG_DATA_HOME="${XDG_DATA_HOME-$HOME/Library/Local/share}"
    XDG_CACHE_HOME="${XDG_CACHE_HOME-$HOME/Library/Caches}"
    MACOS_LIBRARY="${MACOS_LIBRARY-$HOME/Library}"
    PREFIX="${PREFIX-$HOME/Library/Local}"
    PATH="$HOME/Library/Local/bin:$PATH"
else
    XDG_CONFIG_HOME="${XDG_CONFIG_HOME-$HOME/.config}"
    XDG_DATA_HOME="${XDG_DATA_HOME-$HOME/.local/share}"
    XDG_CACHE_HOME="${XDG_CACHE_HOME-$HOME/.cache}"
    MACOS_LIBRARY="${MACOS_LIBRARY-$XDG_DATA_HOME/MacLibrary}"
    PREFIX="${PREFIX-$HOME/.local}"
    PATH="$HOME/.local/bin:$PATH"
fi
. "$XDG_CONFIG_HOME/environment.d/10-applications.conf"
set +a

# EDITOR ----------------------------------------------------------------------
if [ "$OS" = Darwin ] && which vise >/dev/null 2>&1; then
    export EDITOR=vise
elif (which vis && [ "$OS" != Darwin ] || vis -v) >/dev/null 2>&1; then
    export EDITOR=vis
elif which nvim >/dev/null 2>&1; then
    export EDITOR=nvim
elif which vim >/dev/null 2>&1; then
    export EDITOR=vim
fi

# OS-specific options ---------------------------------------------------------
# dotnet in PATH for Fedora
[ -d "/usr/share/dotnet" ] && export PATH="$PATH:/usr/share/dotnet"
# go in PATH
[ -d "$GOPATH/bin" ] && export PATH="$PATH:$GOPATH/bin"

# XDG_RUNTIME_DIR for WSL
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-$XDG_CACHE_HOME/xdgrun}"
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod go-rwx "$XDG_RUNTIME_DIR"
fi

if grep -iq microsoft /proc/version 2>/dev/null; then
    # Extend PATH for ssh to WSL
    PATH="$PATH:$(/mnt/c/Windows/System32/cmd.exe /c 'echo %PATH%' \
        | tr ';' '\n' \
        | grep . \
        | (
            while IFS= read -r REPLY \
                    && [ -n "$(echo "$REPLY"| tr -d '[:space:]')" ]; do
                wslpath -u "$REPLY"
            done
	) \
        | tr '\n' ':')"
elif [ "$OS" = Darwin ]; then
    #MacPorts
    export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
    export MANPATH="/opt/local/share/man:$MANPATH"
fi

# Set-up ----------------------------------------------------------------------
chmod go-rwx "$GNUPGHOME" >/dev/null 2>&1
if [ "$(gpg --list-secret-keys | wc -l)" = 0 ] \
    && [ -f "$GNUPGHOME/keys.asc" ]; then
    killall -s SIGKILL gpg-agent >/dev/null 2>&1
    #generate with gpg --export-secret-keys -a >"$GNUPGHOME/keys.asc"
    (gpg --batch --import "$GNUPGHOME/keys.asc" 2>/dev/null&)
    (
        echo "$(gpg --list-keys --fingerprint 2>/dev/null \
            | grep "michiel@vdnheuvel.com" -B 1 | sed 's/ //g; s/.*=//; 1q' \
        ):6:" | gpg --import-ownertrust 1>/dev/null 2>/dev/null&
    )
    if [ "$OS" = Darwin ]; then
        echo '#!/usr/bin/env sh' >"$PREFIX/bin/gpg"
        echo 'command gpg2 "$@"' >>"$PREFIX/bin/gpg"
        chmod +x "$PREFIX/bin/gpg"
    fi
fi

mkdir -p "$XDG_DATA_HOME/zsh" #For history
mkdir -p "$XDG_DATA_HOME/bash" #For history

mergehistory() {
    set -- "$1" "$2" "$(mktemp)"
    cat "$1" "$2" >"$3" 2>/dev/null
    mv "$3" "$2"
    rm "$1"
}

[ -f "$HOME/.bash_history" ] \
    && (mergehistory "$HOME/.bash_history" "$XDG_DATA_HOME/bash/history"&)
[ -f "$HOME/.zsh_history" ] \
    && (mergehistory "$HOME/.zsh_history" "$XDG_DATA_HOME/zsh/history"&)

[ -f "$XDG_CONFIG_HOME/firefox/user.js" ] && (
    cd ".mozilla/firefox/"*/. 2>/dev/null \
        && ln -f "$XDG_CONFIG_HOME/firefox/user.js"
)

# Services --------------------------------------------------------------------
(! pgrep deluged && deluged&) >/dev/null 2>/dev/null
(! pgrep shairport-sync && shairport-sync&) >/dev/null 2>/dev/null

# Start X ---------------------------------------------------------------------
[ -z "$DISPLAY" ] \
    && [ "0$(fgconsole 2>/dev/null || echo 0)" -eq 1 ] \
    && [ "$(tty)" = '/dev/tty1' ] \
    && startx "$XINITRC"
