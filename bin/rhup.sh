#!/bin/bash
# This script starts the VPN with NetworkManager using the 2FA
# All the required secrets (Tocken PIN and secret, Kerberos password)
# are stored into a pass (https://www.passwordstore.org/) database

# Name of the VPN connection
VPN_CONNECTION="Brno (BRQ)"
# Your Kerberos ID
KRB_ID="pbertera@REDHAT.COM"
# The token PIN
PASS_TOKEN_PIN_PATH="RH/token/pin"
# The token secret
PASS_TOKEN_SECRET_PATH="RH/token/secret"
# The Kerberos password
PASS_KRB_PATH="RH/krb"
# Hexchat network name
# TODO: in case of multiple servers configured we should find a whay to detect the server in use
IRC_NETWORK="irc.eng.brq.redhat.com"
#IRC_NETWORK="chat.freenode.net" # test
IRC_NICK="pbertera"

# define colors in an array
if [[ $BASH_VERSINFO -ge 4 ]]; then
    declare -A c
    c[reset]='\033[0;0m'
    c[grey]='\033[00;30m';  c[GREY]='\033[01;30m';  c[bg_GREY]='\033[40m'
    c[red]='\033[0;31m';    c[RED]='\033[1;31m';    c[bg_RED]='\033[41m'
    c[green]='\E[0;32m';  c[GREEN]='\033[1;32m';  c[bg_GREEN]='\033[42m'
    c[orange]='\033[0;33m'; c[ORANGE]='\033[1;33m'; c[bg_ORANGE]='\033[43m'
    c[blue]='\033[0;34m';   c[BLUE]='\033[1;34m';   c[bg_BLUE]='\033[44m'
    c[purple]='\033[0;35m'; c[PURPLE]='\033[1;35m'; c[bg_PURPLE]='\033[45m'
    c[cyan]='\033[0;36m';   c[CYAN]='\033[1;36m';   c[bg_CYAN]='\033[46m'
fi

# print text to screen
function print {
    # usage:
    # print red WARNING You have encounted an error!
    #
    # returns:
    # [ WARNING ] You have encounted an error!
    #
    # use colors in the array above this function
    local COLOR=$1
    local VERB=$2
    local MSG=$(echo $@ | cut -d' ' -f3-)
    [[ "${MSG: -1}" == "?"  ]] && {
        echo -ne " [${c[$COLOR]}$VERB${c[reset]}] ${MSG::-1}"
    } || {
        echo -e " [${c[$COLOR]}$VERB${c[reset]}] $MSG"
    }
}

# HINT: hexchat, use d-feet to browse the dbus interface

function IRCSetContext {
    local context=$(dbus-send --dest=org.hexchat.service --print-reply --type=method_call /org/hexchat/Remote org.hexchat.plugin.FindContext string:"$IRC_NETWORK" string:"" | tail -n1 | awk '{print $2}')
    dbus-send --dest=org.hexchat.service --type=method_call /org/hexchat/Remote org.hexchat.plugin.SetContext uint32:$context
}

function IRCCommand {
    if [ $# -eq 0 ]; then
        print red ERROR $0 requires a command
        exit 1
    fi
    dbus-send --dest=org.hexchat.service --type=method_call /org/hexchat/Remote org.hexchat.plugin.Command string:"$@"
}

# if the secret isn't found into the defined path will be added
function getPass {
    local passPath="$1"
    pass ls "$passPath" >/dev/null 2>&1 || pass insert "$passPath"
    pass "$passPath"
}

# generate the token TODO: token type should be configurable
function genToken {
    oathtool -b --totp "$TOKEN_SECRET"
}

# set up the VPN
function vpnUp {
    echo "${TOKEN_PIN}$(genToken)" | nmcli --ask connection up "$VPN_CONNECTION"
}

# tear down the VPN
function vpnDown {
    nmcli connection down "$VPN_CONNECTION"
}

# check if the VPN is active
function isVpnUp {
    ping -q -c1 ldap.corp.redhat.com >/dev/null 2>&1
}

# get all the needed secrets
function setup {
    TOKEN_PIN=$(getPass "$PASS_TOKEN_PIN_PATH")
    TOKEN_SECRET=$(getPass "$PASS_TOKEN_SECRET_PATH")
    KRB_PASS=$(getPass "$PASS_KRB_PATH")
}

function usage {
    print red INFO $0 "<up|down|status|getToken|refresh|ircNick>"
}

function status {
    fatalColor=$1
    fatalColor=${fatalColor:-orange}
    isVpnUp
    if [ $? == 0 ]; then
        print green INFO VPN is UP
    else
        print $fatalColor INFO VPN is DOWN
    fi
    shopt -s lastpipe
    klist 2>/dev/null | grep krbtgt | awk '{print $3, $4}'| read krb_token
    if [ ${PIPESTATUS[0]} == 0 ]; then
        print green INFO Kerberos token is valid till $krb_token
    else
        print $fatalColor INFO Kerberos token not present
    fi
}

action="$1"

case "$action" in
    vpnup)
        setup
        vpnUp
        ;;
    vpndown)
        setup
        vpnDown
        ;;
    up)
        setup
        isVpnUp || vpnUp
        echo "$KRB_PASS" | kinit "$KRB_ID">/dev/null
        status red
        IRCSetContext
        IRCCommand "nick $IRC_NICK"
        IRCCommand back
        ;;
    down)
        isVpnUp && vpnDown
        kdestroy
        status
        ;;
    status)
        status
        ;;
    getToken)
        setup
        echo "${TOKEN_PIN}$(genToken)" | xclip
        print orange INFO PIN+Token has been copied into the clipboard for 20 seconds
        sleep 20 && echo -n | xclip & 
        ;;
    ircNick)
        shift
        IRCSetContext
        if [ $# -ne 0 ]; then
            IRC_NICK="$IRC_NICK $@"
        fi
        print white INFO Changing nick to ${IRC_NICK// /|}
        IRCCommand "nick ${IRC_NICK// /|}"
        if [ "$1" == "gone" ] || [ "$1" == "away" ] || [ "$1" == "brb" ]; then
            IRCCommand away
        else
            IRCCommand back
        fi
        ;;
    *)
        usage
        ;;
esac
