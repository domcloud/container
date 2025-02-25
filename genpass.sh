#!/bin/bash

SHARED_PASS=rocky
WEBMIN_USERS_FILE="/etc/webmin/miniserv.users"
BRIDGE_ENV_FILE="/home/bridge/public_html/.env"
WEBMIN_CHANGEPASS=""
for path in /usr/{share,libexec}/webmin/changepass.pl; do
    [[ -x "$path" ]] && WEBMIN_CHANGEPASS="$path" && break
done

generate_password() {
    openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 24
}

test_linux() {
    echo $SHARED_PASS | sudo -S true 2>/dev/null
    [ $? -eq 0 ]
}

test_webmin() {
    WEBMIN_HASH=$(grep "^root:" "$WEBMIN_USERS_FILE" | cut -d: -f2)
    SALT=$(echo "$WEBMIN_HASH" | cut -d'$' -f3)
    GENERATED_HASH=$(openssl passwd -6 -salt "$SALT" "$SHARED_PASS")
    [[ "$WEBMIN_HASH" == "$GENERATED_HASH" ]]
}

test_bridge_unix() {
    echo "$SHARED_PASS" | sudo -S -u bridge true 2>/dev/null
    [ $? -eq 0 ]
}

test_bridge_api() {
    curl -sS 'http://localhost:2223/status/ip'  --connect-timeout 5 \
        --header 'Authorization: Bearer rocky' \
        | jq -e '.granted == true' > /dev/null
}

test_valkey() {
    echo "AUTH root $SHARED_PASS" | valkey-cli &>/dev/null;
}

echo This script change any unchanged password to make your OS secure.
echo ""

echo "[ 1 / 5 ] Checking your linux root password..."
if test_linux; then
    echo "Insecure! Changing your linux root password..."
    NEW_PASS=$(generate_password)
    echo -e "$SHARED_PASS\n$NEW_PASS\n$NEW_PASS" | sudo passwd root >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Password changed successfully."
        echo "New linux root password: $NEW_PASS"
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
    if echo -e "AUTH root $SHARED_PASS\nACL SETUSER root >$NEW_PASS\nACL SAVE" | valkey-cli; then
        echo "Password changed successfully."
        echo "New valkey root password: $SHARED_PASS"
         if [[ -f $BRIDGE_ENV_FILE && -w $BRIDGE_ENV_FILE ]]; then
            sed -i '/^REDIS_URL=/d' "$BRIDGE_ENV_FILE"
            echo "REDIS_URL=\"redis://root:$NEWPASS@localhost:6379\"" >> "$BRIDGE_ENV_FILE"
            echo "Valkey root password has been written to bridge env file"
            systemctl restart bridge || true
        end
    else
        echo "Failed to change valkey root password."
    fi
fi

echo "[ 4 / 5 ] Checking your linux bridge password..."
if test_bridge_unix; then
    echo "Insecure! Changing your linux bridge password..."
    NEW_PASS=$(generate_password)
    echo -e "$SHARED_PASS\n$NEW_PASS\n$NEW_PASS" | sudo passwd bridge >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Password changed successfully."
        echo "New linux bridge password: $NEW_PASS"
    else
        echo "Failed to change linux bridge password."
        exit 1
    fi
fi

echo "[ 5 / 5 ] Checking your API bridge password..."
if test_bridge_unix; then
    echo "Insecure! Changing your API bridge password..."
    NEW_PASS=$(generate_password)
    if [[ -f $BRIDGE_ENV_FILE && -w $BRIDGE_ENV_FILE ]]; then
        sed -i '/^SECRET=/d' "$BRIDGE_ENV_FILE"
        echo "SECRET=$NEW_PASS" >> "$BRIDGE_ENV_FILE"
        echo "Password changed successfully."
        echo "New API bridge password: $NEW_PASS"
        systemctl restart bridge || true
    else
        echo "Failed to change API bridge password."
    fi
fi
