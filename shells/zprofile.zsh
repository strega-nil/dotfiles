if [ -d "/opt/homebrew" ]; then
	eval "$(/opt/homebrew/bin/brew shellenv)"
fi
if [ -d "$HOME/.cargo" ]; then
	. "$HOME/.cargo/env"
fi
if [ -d "$HOME/.local/bin" ]; then
	export PATH="$PATH:$HOME/.local/bin"
fi
if [ -d "$HOME/.local/llvm/current/bin" ]; then
	export PATH="$PATH:$HOME/.local/llvm/current/bin"
fi
if [ -d "$HOME/.local/ndk" ]; then
	export PATH="$PATH:$HOME/.local/ndk/cmdline-tools/latest/bin"
fi

export VISUAL="nvim"
export EDITOR="$VISUAL"

# set up gpg
export GPG_TTY=`tty`
gpgconf --launch gpg-agent
if [ ! -e "$HOME/.config/misc/is-work" ]; then
	export SSH_AUTH_SOCK=`gpgconf --list-dirs agent-ssh-socket`
fi

