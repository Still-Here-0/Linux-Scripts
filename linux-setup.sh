#!/bin/bash

declare system
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

    log "Loading apps"
    load_apps

    log "Installing apps"
    install_apps
}

function set_system {

    if [[ -f /etc/debian_version ]]; then       # Main distros
        system=1
    elif [[ -f /etc/redhat-release ]]; then     # 
        system=2
        log "This script is not supported in RedHat based distros yet" 2
        exit 1
    elif [[ -f /etc/arch-release ]]; then       # 
        system=3
        log "This script is not supported in Arch based distros yet" 2
        exit 1
    else
        log "Unsupported Linux distribution. Exiting." 2
        exit 1
    fi

    log "System set as '$system'" 1
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
    code_ins['vscode']="install_vscode, apt, , "
    # python - pyenv
    # rust - cargo

    total=$((total + ${#code_ins[@]}))

    # GAMES
    game_ins['lutris']=", apt, , "
    # Albion
    game_ins['com.pokemmo.PokeMMO']=", flatpak, flatpak, "
    game_ins['at.vintagestory.VintageStory']=", flatpak, flatpak, "
    game_ins['steam-installer']=", apt, , "

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

# region Install apps

function install_app {
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
            eval "${options[0]} ${options[1]} ${options[2]} ${options[3]}"
        fi

    done
}

function common_app_install {

    local app_name=$1
    local pkg_manager=$2

    local install_command
    case $pkg_manager in
        apt)
            install_command="sudo apt install -y $app_name"
            ;;
        flatpak)
            install_command="flatpak install -y flathub $app_name"
            ;;
        dnf)
            install_command="sudo dnf install -y $app_name"
            ;;
        pacman)
            install_command="sudo pacman -Syu --noconfirm $app_name"
            ;;
        yay)
            install_command="yay -S --noconfirm $app_name"
            ;;
        *)
            log "Error: Unsupported package manager '$pkg_manager' for '$app_name'" 2
            return 1
            ;;
    esac

    log "Installing $app_name using $pkg_manager..."
    if ! eval "$install_command"; then
        log "Failed to install $app_name using $pkg_manager" 2
        return 1
    fi

    log "Successfully installed $app_name using $pkg_manager" 0
}

function install_vscode {

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
    common_app_install "./vscode.$sulfix" "$pkg_manager"
    
    # Remove installed file
    rm "vscode.$sulfix"
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

# endregion

log "INITIALIZING INSTALLATION" 0
main
log "ALL DONE" 0