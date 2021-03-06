# sh/profile.sh - session for POSIX shells
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
    XDG_CACHE_HOME="${XDG_CACHE_HOME-$HOME/Library/Caches}"
    MACOS_LIBRARY="${MACOS_LIBRARY-$HOME/Library}"
    PREFIX="${PREFIX-$HOME/Library/Local}"
    eval "$(locale)"
else
    XDG_CONFIG_HOME="${XDG_CONFIG_HOME-$HOME/.config}"
    XDG_CACHE_HOME="${XDG_CACHE_HOME-$HOME/.cache}"
    PREFIX="${PREFIX-$HOME/.local}"
fi
XDG_BIN_HOME="${XDG_BIN_HOME-$PREFIX/bin}"
XDG_DATA_HOME="${XDG_DATA_HOME-$PREFIX/share}"
. "$XDG_CONFIG_HOME/environment.d/10-applications.conf"
if command -v python3 >/dev/null 2>&1; then
    PATH="$PATH:$(python3 -m site --user-base)/bin"
fi
PATH="$PATH:$XDG_DATA_HOME/npm/bin"
PATH="$PATH:$XDG_DATA_HOME/cargo/bin"
PATH="$XDG_BIN_HOME:$PATH:$GOPATH/bin:$PREFIX/lib/sh/lazyload"
PATH="$PATH:$PREFIX/lib/sh/polyfill/$OS"
set +a

# SSH/GPG ---------------------------------------------------------------------
(command -v pinentry-mac || command -v pinentry-curses 2>/dev/null) \
    | sed 's/^/pinentry-program /' \
    | cat "$GNUPGHOME/gpg-agent-base.conf" - \
    >"$GNUPGHOME/gpg-agent.conf"

if command -v gpgconf >/dev/null 2>&1; then
    export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
fi

# OS-specific options ---------------------------------------------------------
# dotnet in PATH for Fedora
[ -d "/usr/share/dotnet" ] && export PATH="$PATH:/usr/share/dotnet"

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
    cp "$XDG_CONFIG_HOME/vim/vsvimrc" "$(winenvdir USERPROFILE)/.vsvimrc"
    cp "$XDG_CONFIG_HOME/vim/ideavimrc" "$(winenvdir USERPROFILE)/.ideavimrc"
elif [ "$OS" = Darwin ]; then
    #MacPorts
    export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
    export MANPATH="/opt/local/share/man:$MANPATH"
fi

# Set-up ----------------------------------------------------------------------
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

# Services --------------------------------------------------------------------
(pgrep deluged || deluged&) >/dev/null 2>&1
(pgrep shairport-sync || shairport-sync&) >/dev/null 2>&1
(pgrep -f yt_music_log || yt_music_log&) >/dev/null 2>&1
(winvm default up&) >/dev/null 2>&1

# Start X ---------------------------------------------------------------------
[ -z "$DISPLAY" ] \
    && [ "0$(fgconsole 2>/dev/null || echo 0)" -eq 1 ] \
    && [ "$(tty)" = '/dev/tty1' ] \
    && sway
case "$(tty)" in
    /dev/tty*) command -v loadkeys >/dev/null @>&1 \
        && dumpkeys | sed 's/Caps_Lock/Escape/' | sudo loadkeys;;
esac
