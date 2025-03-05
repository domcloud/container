#!/bin/bash

if [ -z "$(echo $BASH_VERSION$ZSH_VERSION)" ]; then
    echo "❌ This script requires Bash or Zsh!" >&2
    exit 1
fi

if [[ "$(id -u)" -ne 0 ]]; then
    echo "❌ This script must be run as root!" >&2
    exit 1
fi

if [ -f /etc/lsb-release ]; then OS=ubuntu; elif [ -f /etc/redhat-release ]; then OS=rocky; else OS=unknown; fi
SHARED_PASS="${SHARED_PASS:-$OS}"
WEBMIN_USERS_FILE="/etc/webmin/miniserv.users"
SHADOW_FILE="/etc/shadow"
BRIDGE_ENV_FILE="/home/bridge/public_html/.env"
WEBMIN_CHANGEPASS=""
for path in /usr/{share,libexec}/webmin/changepass.pl; do
    [[ -x "$path" ]] && WEBMIN_CHANGEPASS="$path" && break
done

generate_password() {
    openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 24
}

test_password() {
    local user="$1"
    local file="$2"

    [[ -f "$file" ]] || return 1  # Exit if file does not exist

    PASSHASH=$(grep "^$user:" "$file" | cut -d: -f2)
    [[ -n "$PASSHASH" ]] || return 1  # Exit if no hash found

    SALT=$(echo "$PASSHASH" | cut -d'$' -f3)
    GENERATED_HASH=$(openssl passwd -6 -salt "$SALT" "$SHARED_PASS")

    [[ "$PASSHASH" == "$GENERATED_HASH" ]]
}

# Reuse function for each case
test_linux() { test_password "root" "$SHADOW_FILE"; }
test_webmin() { test_password "root" "$WEBMIN_USERS_FILE"; }
test_bridge_unix() { test_password "bridge" "$SHADOW_FILE"; }

test_bridge_api() {
    curl -sS 'http://127.0.0.1:2223/status/ip' --connect-timeout 5 \
        --header "Authorization: Bearer $SHARED_PASS" \
        | jq -e '.granted == true' > /dev/null
}

test_valkey() {
    echo -e "AUTH root $SHARED_PASS\nPING" | valkey-cli | grep PONG &>/dev/null;
    [ $? -eq 0 ]
}

echo This script detect if you haven\'t change any password in this OS then perform changes it for you.
echo ""

echo "[ 1 / 5 ] Checking your linux root password..."
if test_linux; then
    echo "Insecure! Changing your linux root password..."
    NEW_PASS=$(generate_password)
    echo -e "$NEW_PASS\n$NEW_PASS" | sudo passwd root >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Password changed successfully."
        echo "New linux root password: $NEW_PASS"
        echo KEEP THIS LINUX ROOT PASSWORD OR RISK LOCKED OUT
    else
        echo "Failed to change linux root password."
        exit 1
    fi
fi

echo "[ 2 / 5 ] Checking your webmin root password..."
if test_webmin; then
    echo "Insecure! Changing your webmin root password..."
    NEW_PASS=$(generate_password)
    $WEBMIN_CHANGEPASS /etc/webmin root $NEW_PASS
    if [ $? -eq 0 ]; then
        echo "Password changed successfully."
        echo "New webmin root password: $NEW_PASS"
    else
        echo "Failed to change webmin root password."
        exit 1
    fi
fi

echo "[ 3 / 5 ] Checking your valkey root password..."
if test_valkey; then
    echo "Insecure! Changing your valkey root password..."
    NEW_PASS=$(generate_password)
    if echo -e "AUTH root $SHARED_PASS\nACL SETUSER root resetpass >$NEW_PASS\nACL SAVE\nPING" | valkey-cli | grep PONG &>/dev/null; then
        echo "Password changed successfully."
        echo "New valkey root password: $NEW_PASS"
        if [[ -f $BRIDGE_ENV_FILE && -w $BRIDGE_ENV_FILE ]]; then
            sed -i '/^REDIS_URL=/d' "$BRIDGE_ENV_FILE"
            echo "REDIS_URL=\"redis://root:$NEW_PASS@localhost:6379\"" >> "$BRIDGE_ENV_FILE"
            echo "Valkey root password has been written to bridge env file"
            NEED_RESTART_BRIDGE=1
        fi
    else
        echo "Failed to change valkey root password."
    fi
fi

echo "[ 4 / 5 ] Checking your linux bridge password..."
if test_bridge_unix; then
    echo "Insecure! Changing your linux bridge password..."
    NEW_PASS=$(generate_password)
    echo -e "$NEW_PASS\n$NEW_PASS" | sudo passwd bridge >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Password changed successfully."
        echo "New linux bridge password: $NEW_PASS"
    else
        echo "Failed to change linux bridge password."
        exit 1
    fi
fi

echo "[ 5 / 5 ] Checking your API bridge password..."
if test_bridge_api; then
    echo "Insecure! Changing your API bridge password..."
    NEW_PASS=$(generate_password)
    if [[ -f $BRIDGE_ENV_FILE && -w $BRIDGE_ENV_FILE ]]; then
        sed -i '/^SECRET=/d' "$BRIDGE_ENV_FILE"
        echo "SECRET=$NEW_PASS" >> "$BRIDGE_ENV_FILE"
        echo "Password changed successfully."
        echo "New API bridge password: $NEW_PASS"
        NEED_RESTART_BRIDGE=1
    else
        echo "Failed to change API bridge password."
    fi
fi

if [[ "$NEED_RESTART_BRIDGE" == "1" ]]; then
    echo "Restarting bridge service..."
    systemctl restart bridge || true
fi
