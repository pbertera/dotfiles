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

# if the secret isn't found into the defined path will be added
function getPass {
    local passPath="$1"
    pass ls "$passPath" >/dev/null 2>&1 || pass insert "$passPath"
    pass "$passPath"
}

function genToken {
    oathtool -b --totp "$TOKEN_SECRET"
}

function vpnUp {
    echo "${TOKEN_PIN}$(genToken)" | nmcli --ask connection up "$VPN_CONNECTION"
}

function isVpnUp {
    ping -q -c1 ldap.corp.redhat.com >/dev/null 2>&1
}

TOKEN_PIN=$(getPass "$PASS_TOKEN_PIN_PATH")
TOKEN_SECRET=$(getPass "$PASS_TOKEN_SECRET_PATH")
KRB_PASS=$(getPass "$PASS_KRB_PATH")

isVpnUp || vpnUp

echo "$KRB_PASS" | kinit "$KRB_ID">/dev/null
klist
