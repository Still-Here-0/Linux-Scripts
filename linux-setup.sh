#!/bin/bash

# System
declare system
declare -A commands_checks

# Apps
declare -A base_ins
declare -A code_ins
declare -A game_ins
declare -A util_ins

function main {
    if ! sudo -v; then
        log "No sudo access given. Exiting." 2
        exit 1
    fi

    # Determine OS name
    local os
    os=$(uname)

    if [ "$os" != "Linux" ]; then
        log "This file only works in Linux machines" 3
        exit 1
    fi

    log "Loading system info"
    set_system

    log "Starting app installation"
    start_install

    log "Starting setup process"
    start_setup
}

function set_system {

    local sys_name
    if [[ -f /etc/debian_version ]]; then       # Main distros
        sys_name="debian"
        system=1
    elif [[ -f /etc/redhat-release ]]; then     # 
        sys_name="redhat"
        system=2
        log "This script is not supported in RedHat based distros yet" 2
        exit 1
    elif [[ -f /etc/arch-release ]]; then       # 
        sys_name="arch"
        system=3
        log "This script is not supported in Arch based distros yet" 2
        exit 1
    else
        log "Unsupported Linux distribution. Exiting." 2
        exit 1
    fi

    log "System set as $system -> $sys_name" 1
}

# region Install apps

function start_install {
    log "Loading apps"
    load_apps

    log "Installing apps"
    install_apps
}

function load_apps {

    local total=0

    # {'app': 'specific_function', 'debian_distro', 'redhat_distro', 'arch_distro'}

    # BASE
    base_ins['vlc']=", apt, , "
    base_ins['gnome-clocks']=", apt, , "
    base_ins['org.qbittorrent.qBittorrent']=", flatpak, flatpak, "
    base_ins['dropbox']=", apt, , "
    base_ins['xyz.z3ntu.razergenie']=", flatpak, flatpak, "

    total=$((total + ${#base_ins[@]}))

    # CODE
    code_ins['git']=", apt, , "
    code_ins['code']="install_code, apt, , "  # vscode
    code_ins['pyenv']="install_pyenv, ., , "    # python
    code_ins['cargo']="install_cargo, ., , "    # rust

    total=$((total + ${#code_ins[@]}))

    # GAMES
    game_ins['com.albiononline.AlbionOnline']=", flatpak, flatpak, "
    game_ins['com.pokemmo.PokeMMO']=", flatpak, flatpak, "
    game_ins['at.vintagestory.VintageStory']=", flatpak, flatpak, "
    game_ins['steam-installer']=", apt, , "
    game_ins['lutris']=", apt, , "
    game_ins['guild-wars-2']="install_gw, lutris, lutris, lutris"

    total=$((total + ${#game_ins[@]}))

    # UTILS
    util_ins['com.discordapp.Discord']=", flatpak, flatpak, "
    util_ins['md.obsidian.Obsidian']=", flatpak, flatpak, "
    util_ins['blender']=", apt, , "
    util_ins['flameshot']=", apt, , "
    util_ins['com.obsproject.Studio']=", flatpak, flatpak, "
    util_ins['xournal']=", apt, , "
    util_ins['org.kicad.KiCad']=", flatpak, flatpak, "
    util_ins['com.brave.Browser']=", flatpak, flatpak, "

    total=$((total + ${#util_ins[@]}))

    log "$total apps will be installed"
}

function install_apps {
    install_list "base_ins"
    install_list "code_ins"
    install_list "game_ins"
    install_list "util_ins"
}

function install_list {
    local array_name=$1
    local -n array=$array_name

    for app in "${!array[@]}"; do
        IFS=', ' read -r -a options <<< "${array[$app]}"

        if [[ -z "${options[$system]}" ]]; then
            log "No package manager for $app in system $system" 1
            continue
        fi

        if [[ -z "${options[0]}" ]]; then
            common_app_install "$app" "${options[$system]}"
        else
            eval "${options[0]} ${options[1]} ${options[2]} ${options[3]}" # Especial install function
        fi

    done
}

function common_app_install {

    local app_name=$1       # dot_file name of app_name from repo
    local pkg_manager=$2
    local installation_name=${3:-$1}  # name of installed app

    if ! is_command_valid "$pkg_manager" 0; then
        log "'$pkg_manager' can not be found"
        return 1
    fi

    local check_command
    local install_command
    case $pkg_manager in
        apt)
            check_command="dpkg -s $installation_name > /dev/null"
            install_command="apt install -y $app_name"
            ;;
        flatpak)
            check_command="flatpak list --app | grep -q $installation_name"
            install_command="flatpak install -y flathub $app_name"
            ;;
        dnf)
            install_command="dnf install -y $app_name"
            ;;
        pacman)
            install_command="pacman -Syu --noconfirm $app_name"
            ;;
        yay)
            install_command="yay -S --noconfirm $app_name"
            ;;
        *)
            log "Error: Unsupported package manager '$pkg_manager' for '$app_name'" 2
            return 1
            ;;
    esac

    if [[ -z "$check_command" ]]; then
        log "No check function defined for $pkg_manager" 1
    elif eval "$check_command"; then # TRUE if is installed
        log "$installation_name is already installed in $pkg_manager" 1
        return 0
    fi

    log "Installing $app_name using $pkg_manager..."
    if ! eval "$install_command"; then
        log "Failed to install $app_name using $pkg_manager" 2
        return 1
    fi

    log "Successfully installed $app_name using $pkg_manager" 0
}

function common_lutris_install {
    local lutris_url=$1
    local app_name=$2

    if ! is_command_valid "lutris" 0; then
        log "Lutris is not installed" 1
        return 0
    elif lutris -l 2> /dev/null | grep -qi "$app_name"; then # 2> /dev/null : silence error output
        log "$app_name is already installed in lutris. Skipping installation." 1
        return 0
    fi
    
    log "test1"
    lutris -i "$lutris_url"
    log "test2"
}

function install_code {

    local sulfix
    local id
    local pkg_manager    
    if [[ $system == 1 ]]; then
        sulfix="deb"
        id="760868"
        pkg_manager=$1
    elif [[ $system == 2 ]]; then
        sulfix="rpm"
        id="760847"
        pkg_manager=$2
    elif [[ $system == 3 ]]; then
        log "Visual Studio Code installation is not directly supported for pacman." 1
        return 1
    fi

    # Get package from microsoft web site
    # Check if download was a success
    log "Downloading vscode installer"
    if ! wget -q "https://go.microsoft.com/fwlink/?LinkID=$id" -O "vscode.$sulfix"; then
        log "Error: Failed to install Visual Studio Code." 2
        return 1
    fi
    
    # Install vs code from downloaded file
    common_app_install "./vscode.$sulfix" "$pkg_manager" "code"
    
    # Remove installed file
    rm "vscode.$sulfix"
}

function install_gw {
    common_lutris_install "https://lutris.net/api/installers/guild-wars-2-standard.yml"
}

function install_pyenv {

    if is_command_valid pyenv; then
        log "Pyenv is already installed" 1
        return 0
    elif ! is_command_valid apt; then
        log "apt not not installed" 2
        return 1
    fi

    # Installing dependencies
    apt install build-essential libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev curl git \
    libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

    # Pyenv script install
    curl https://pyenv.run | bash

    # Set up pyenv in shell
    {
        echo "export PYENV_ROOT=\"$HOME/.pyenv\""
        echo "command -v pyenv >/dev/null || export PATH=\"$PYENV_ROOT/bin:$PATH\""
        echo "eval \"$(pyenv init -)\""
    } >> ~/.bashrc

    # Set up pyenv in profile
    {
        echo "export PYENV_ROOT=\"$HOME/.pyenv\""
        echo "command -v pyenv >/dev/null || export PATH=\"$PYENV_ROOT/bin:$PATH\""
        echo "eval \"$(pyenv init -)\""
    } >> ~/.profile


}

function install_cargo {
    if is_command_valid cargo; then
        log "Cargo is already installed" 1
        return 0
    fi

    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
}

function install_yay {
    log "Installing yay (AUR helper)..."
    sudo pacman -Syu --noconfirm git base-devel
    (
        git clone https://aur.archlinux.org/yay.git
        cd yay || { log "Failed to change directory to 'yay'. Exiting." 2; exit 1; }
        makepkg -si --noconfirm
        rm -rf yay
    )
    log "Successfully installed yay" 0
}

# endregion

# region setup

function start_setup {
    setup_system
    setup_pyenv
    setup_code
}

function setup_system {
    .
}

function setup_pyenv {
    
    # 
    alias py='python3'
}

function setup_code {
    .
}

# endregion

# region Utils

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

function log {
    local color
    
    if [[ -z $2 ]]; then            # NORMAL
        color=$BLUE
    elif [[ $2 == 0 ]]; then        # SUCCESS
        color=$GREEN
    elif [[ $2 == 1 ]]; then        # WARNING
        color=$YELLOW
    elif [[ $2 == 2 ]]; then        # ERROR
        color=$RED
    else
        color="$MAGENTA (ERROR: invalid log level: $2)"
    fi

    echo -e "$color$(date '+%Y-%m-%d %H:%M:%S'): $1$NC"
}

function is_command_valid { # TODO: rever
    local command=$1
    local save=${2:-1}

    if [[ -n "${commands_checks[$command]}" ]]; then
        
        return "${commands_checks[$command]}"

    elif [[ $save -eq 0 || -z "${commands_checks[$command]}" ]]; then
        
        if command -v "$command" > /dev/null; then
            commands_checks[$command]=0 # True
        else
            commands_checks[$command]=1 # False
        fi

        return "${commands_checks[$command]}"
    
    else
        if command -v "$command" > /dev/null; then
            return 0 # True
        else
            return 1 # False
        fi
    fi
}

# endregion

log "INITIALIZING INSTALLATION" 0
main
log "ALL DONE" 0