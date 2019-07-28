[[ -n "$OS" ]] \
    || emulate sh -c '. "${XDG_CONFIG_HOME:-$HOME/.config}/shell/profile.sh"'
[[ -f "$XDG_CONFIG_HOME/shell/rc.sh" ]] \
    && emulate sh -c '. "$XDG_CONFIG_HOME/shell/rc.sh"'

# History ---------------------------------------------------------------------
HISTFILE="$XDG_DATA_HOME/zsh/history"
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_FIND_NO_DUPS
setopt appendhistory

# Fuzzy find ------------------------------------------------------------------
if command -v fzy >/dev/null 2>&1; then
    function fzy-history-widget {
        BUFFER="$(fc -lnr 1 \
            | sed 's/^[ \t]*//' \
            | awk '!seen[$0]++'\
            | fzy )"
        CURSOR=$#BUFFER #Move cursor to end of line. Looks nice
        
        zle redisplay #Make sure the prompt is still there
    }

    function fzy-branch-widget {
        BUFFER="$BUFFER$(git for-each-ref --sort=-committerdate refs/heads/ \
                refs/remotes --format='%(refname:short)' \
            | sed 's/^origin\///' \
            | awk '!seen[$0]++'\
            | fzy )"
        CURSOR=$#BUFFER
        zle redisplay
    }

    zle -N fzy-history-widget
    zle -N fzy-branch-widget
    bindkey -M viins '^R' fzy-history-widget
    bindkey -M vicmd '^R' fzy-history-widget
    bindkey -M viins '^B' fzy-branch-widget
    bindkey -M vicmd '^B' fzy-branch-widget
fi

# Prompt definition -----------------------------------------------------------
if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    PROMPT='%B%n@%m %1~%(?..%F{red})%#%f%b '
else
    PROMPT='%B%1~%(?..%F{red})%#%f%b '
fi
zle_highlight=(default:bold)

function precmd {
    RPROMPT="$(git_promptline)"
}

MAILCHECK=0

# Input customization ---------------------------------------------------------
if [ "$TERM" = "linux" ]; then
    cursor_ins="\033[?5c"
    cursor_cmd="\033[?6c"
else
    cursor_ins="\033[6 q"
    cursor_cmd="\033[2 q"
fi

function zle-keymap-select {
    if [ $KEYMAP = vicmd ]; then
        printf "$cursor_cmd"
    else
        printf "$cursor_ins"
    fi
}
function zle-line-init {
    zle -K viins
    printf "$cursor_ins"
}
function zle-line-finish {
    printf "$cursor_cmd"
}
zle -N zle-keymap-select
zle -N zle-line-init
zle -N zle-line-finish

function bindkey-ctrl2esc {
    eval "function zle-ctrl2esc-$2 { zle vi-cmd-mode; zle $2; };"
    zle -N "zle-ctrl2esc-$2"
    bindkey -M viins "$1" "zle-ctrl2esc-$2"
}
bindkey -v
bindkey -M viins '^?' backward-delete-char
bindkey -M viins '^H' backward-delete-char
bindkey-ctrl2esc '^K' up-line-or-history

backward-kill-dir () {
    local WORDCHARS=${WORDCHARS/\/}
    zle backward-kill-word
}
zle -N backward-kill-dir
bindkey '^W' backward-kill-dir

bindkey -M vicmd 'gj' vi-fetch-history
bindkey -M vicmd 'gk' beginning-of-buffer-or-history
bindkey -M vicmd 'gh' vi-beginning-of-line
bindkey -M vicmd 'gl' vi-end-of-line

# Completion ------------------------------------------------------------------
fpath=("$XDG_DATA_HOME/zsh/site-functions" $fpath)
emulate sh -c '(chmod -R go-w "$XDG_DATA_HOME/zsh" &)'

zstyle ':completion:*' completer _complete _ignored
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list 'm:{[:lower:]}={[:upper:]}'
zstyle :compinstall filename "$HOME"'/.zshrc'

autoload -Uz compinit

for dump in ~/.zcompdump(N.mh+24); do
  compinit
done

compinit -C
unsetopt beep notify BG_NICE
setopt interactivecomments
