ARCH="$(uname -m)"
case "$ARCH" in 
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    armv7l) ARCH="arm" ;;
    *) echo "Unsupported architecture" ;;
esac

BASE_PATH="$HOME/.localrtsp/"
mkdir -p $BASE_PATH
BINARY_PATH="$BASE_PATH"mediamtx
CONFIG_PATH="$BASE_PATH"mediamtx.yml
LICENSE_PATH="$BASE_PATH"LICENSE
URL_BASE="https://raw.githubusercontent.com/DurancOy/duranc_bootstrap/master/gateway/mediamtx/"
SHA256_BINARY_URL="$URL_BASE"mediamtx_"$ARCH"_sha256
DOWNLOAD_BINARY_URL="$URL_BASE"mediamtx_"$ARCH"
CONFIG_VERSION_URL="$URL_BASE"CONF_VERSION
DOWNLOAD_CONF_URL="$URL_BASE"mediamtx.yml
LICENSE_URL="$URL_BASE"LICENSE

CURRENT_BINARY_SHA256=""
REMOTE_BINARY_SHA256="$(curl -s "$SHA256_BINARY_URL")"
if [ -f "$BINARY_PATH" ]; then
    CURRENT_BINARY_SHA256="$(sha256sum "$BINARY_PATH" | awk '{ print $1 }')"
fi
if [ "$CURRENT_BINARY_SHA256" == "$REMOTE_BINARY_SHA256" ]; then
    echo "Mediamtx binary file is up to date"
else
    echo "Updating mediamtx binary file..."
    curl -s "$DOWNLOAD_BINARY_URL" -o "$BINARY_PATH"
    chmod +x "$BINARY_PATH"
fi

CURRENT_CONFIG_VERSION="0"
REMOTE_CONFIG_VERSION="$(curl -s "$CONFIG_VERSION_URL")"
if [ -f "$CONFIG_PATH" ]; then
    CURRENT_CONFIG_VERSION="$(sed -n '1p' $CONFIG_PATH | cut -d'=' -f2)"
fi
if [[ $CURRENT_CONFIG_VERSION =~ [^0-9]+ ]]; then
    CURRENT_CONFIG_VERSION="0"
fi
if [ $REMOTE_CONFIG_VERSION -gt $CURRENT_CONFIG_VERSION ]; then
    echo "Updating mediamtx configuration file... from "$CURRENT_CONFIG_VERSION" to  "$REMOTE_CONFIG_VERSION
    curl -s "$DOWNLOAD_CONF_URL" -o "$CONFIG_PATH"
    PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
    sed -i "s/apiuser: PASSWORD_PLACEHOLDER/apiuser: $PASSWORD/g" $CONFIG_PATH
else
    echo "Mediamtx configuration file is up to date"
fi

echo "Updating mediamtx license file..."
curl -s "$LICENSE_URL" -o "$LICENSE_PATH"
echo "Mediamtx install end."