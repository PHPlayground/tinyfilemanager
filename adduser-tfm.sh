#!/bin/bash

# +-------------------------------------------------------------------------+
# | Simple command line to add new user for TinyFileManager                 |
# +-------------------------------------------------------------------------+
# | Copyright (c) 2019 ESLabs (https://eslabs.id)                           |
# +-------------------------------------------------------------------------+
# | This source file is subject to the GNU General Public License           |
# | that is bundled with this package in the file LICENSE.md.               |
# |                                                                         |
# | If you did not receive a copy of the license and are unable to          |
# | obtain it through the world-wide-web, please send an email              |
# | to license@eslabs.id so we can send you a copy immediately.             |
# +-------------------------------------------------------------------------+
# | Authors: Edi Septriyanto <eslabs.id@gmail.com>                          |
# +-------------------------------------------------------------------------+

set -e

# Version Control.
APP_NAME=$(basename "$0")
APP_VERSION="1.3.0"

USERNAME=$1
PASSWORD=$2
PASSHASH=""
ALGO="PASSWORD_DEFAULT"

#BASE_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TFM_DIR="/usr/share/nginx/html/lcp/filemanager"
#STORAGE_DIR="storage"
#STORAGE_PATH="${BASE_DIR}/${STORAGE_DIR}"
STORAGE_PATH="/home"

if [[ -z "${USERNAME}" || -z "${PASSWORD}" ]]; then
    echo -e "USERNAME or PASSWORD is required.\nCommand: ${APP_NAME} username password"
    exit 1
fi

if [[ -z $(getent passwd "${USERNAME}") ]]; then
    echo "System account for ${USERNAME} not found. Attempts to create it..."
    
    useradd -d "/home/${USERNAME}" -m -s /bin/bash "${USERNAME}"
    echo "${USERNAME}:${PASSWORD}" | chpasswd

    # Create default directories.
    mkdir -p "/home/${USERNAME}/webapps"
    chown -hR "${USERNAME}:${USERNAME}" "/home/${USERNAME}"

    # Add account credentials to /srv/.htpasswd.
    if [ ! -f "/srv/.htpasswd" ]; then
        touch /srv/.htpasswd
    fi

    # Generate passhword hash.
    if [[ -n $(command -v mkpasswd) ]]; then
        PASSWORD_HASH=$(mkpasswd --method=sha-256 "${PASSWORD}")
        sed -i "/^${USERNAME}:/d" /srv/.htpasswd
        echo "${USERNAME}:${PASSWORD_HASH}" >> /srv/.htpasswd
    elif [[ -n $(command -v htpasswd) ]]; then
        htpasswd -b /srv/.htpasswd "${USERNAME}" "${PASSWORD}"
    else
        PASSWORD_HASH=$(openssl passwd -1 "${PASSWORD}")
        sed -i "/^${USERNAME}:/d" /srv/.htpasswd
        echo "${USERNAME}:${PASSWORD_HASH}" >> /srv/.htpasswd
    fi
fi

# Update TFM config #

TFMUSEREXIST=$(grep -qwE "${USERNAME}" "${TFM_DIR}/config/auth.php" && echo true || echo false)

if [[ "${TFMUSEREXIST}" == false ]]; then
    if [[ -n $(command -v php) ]]; then
        PHP_CMD="echo password_hash(\"${PASSWORD}\", ${ALGO});"
        PASSHASH=$(php -r "${PHP_CMD}")
    fi

    # add new user auth
    sed -i "/^];/i \    '${USERNAME}'\ =>\ '${PASSHASH}'," "${TFM_DIR}/config/auth.php"

    # add new user directory
    #USER_STORAGE_DIR="${STORAGE_DIR}/${USERNAME}"
    USER_STORAGE_PATH="${STORAGE_PATH}/${USERNAME}"

    if [[ ! -d "${USER_STORAGE_PATH}" ]]; then
        mkdir -p "${USER_STORAGE_PATH}"
    fi
    chown -hR "${USERNAME}":"${USERNAME}" "${USER_STORAGE_PATH}"

    #sed -i "/^];/i \    '${USERNAME}'\ =>\ '${USER_STORAGE_DIR}'," config/directories.php
    sed -i "/^];/i \    '${USERNAME}'\ =>\ '${USER_STORAGE_PATH}'," "${TFM_DIR}/config/directories.php"

    echo -e "New user has been added to the TFM auth config.\n
USERNAME: $USERNAME
PASSWORD: $PASSWORD
PASSWORD Hash: $PASSHASH
Directory Path: $USER_STORAGE_PATH"
else
    echo "User $USERNAME already exists"
fi

