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

# May need to run this as sudo!
# I have it in /usr/local/bin and run command 'ngxvhost' from anywhere, using sudo.
if [ "$(id -u)" -ne 0 ]; then
    echo "This command can only be used by root."
    exit 1  #error
fi

# Version Control.
APP_NAME=$(basename "$0")
#APP_VERSION="1.3.0"

USERNAME=$1
PASSWORD=$2
PASSHASH=""
ALGO="PASSWORD_DEFAULT"

# Export LEMPer config.
if [ -f /etc/lemper.conf ]; then
    # Clean environemnt first.
    # shellcheck source=.env.dist
    # shellcheck disable=SC2046
    unset $(grep -v '^#' /etc/lemper.conf | grep -v '^\[' | sed -E 's/(.*)=.*/\1/' | xargs)

    # shellcheck source=.env.dist
    # shellcheck disable=SC1091
    # shellcheck disable=SC1094
    source <(grep -v '^#' /etc/lemper.conf | grep -v '^\[' | sed -E 's|^(.+)=(.*)$|: ${\1=\2}; export \1|g')
fi

#BASE_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TFM_DIR="/usr/share/nginx/html/lcp/filemanager"
#STORAGE_DIR="storage"
#STORAGE_PATH="${BASE_DIR}/${STORAGE_DIR}"
STORAGE_PATH="/home"

if [[ -z "${USERNAME}" || -z "${PASSWORD}" ]]; then
    echo -e "USERNAME or PASSWORD is required.\nCommand: ${APP_NAME} username password"
    exit 1
fi

#USER_STORAGE_DIR="${STORAGE_DIR}/${USERNAME}"
USER_STORAGE_PATH="${STORAGE_PATH}/${USERNAME}"

if [[ -z $(getent passwd "${USERNAME}") ]]; then
    echo "System account for ${USERNAME} not found. Attempts to create it..."
    
    useradd -d "${USER_STORAGE_PATH}" -m -s /bin/bash "${USERNAME}"
    echo "${USERNAME}:${PASSWORD}" | chpasswd

    # Create default directories.
    [ ! -d "${USER_STORAGE_PATH}/webapps" ] && \
    mkdir -p "${USER_STORAGE_PATH}/webapps" && \
    chown -hR "${USERNAME}:${USERNAME}" "${USER_STORAGE_PATH}"

    # Add account credentials to /srv/.htpasswd.
    if [ ! -f /srv/.htpasswd ]; then
        touch /srv/.htpasswd
    fi

    # Generate password hash.
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

TFM_USER_EXIST=$(grep -qwE "${USERNAME}" "${TFM_DIR}/config/auth.php" && echo true || echo false)
if [[ ${TFM_USER_EXIST} == false ]]; then
    echo "Create file manager account for ${USERNAME}"

    if [[ -n $(command -v php) ]]; then
        PHP_CMD="echo password_hash(\"${PASSWORD}\", ${ALGO});"
        PASSHASH=$(php -r "${PHP_CMD}")
    fi

    # Add new user auth to TFM config.
    sed -i "/^];/i \    '${USERNAME}'\ =>\ '${PASSHASH}'," "${TFM_DIR}/config/auth.php"

    # Add new user directory to TFM config.
    if [[ ! -d "${USER_STORAGE_PATH}" ]]; then
        mkdir -p "${USER_STORAGE_PATH}"
    fi

    chown -hR "${USERNAME}":"${USERNAME}" "${USER_STORAGE_PATH}"

    #sed -i "/^];/i \    '${USERNAME}'\ =>\ '${USER_STORAGE_DIR}'," config/directories.php
    sed -i "/^];/i \    '${USERNAME}'\ =>\ '${USER_STORAGE_PATH}'," "${TFM_DIR}/config/directories.php"

    echo -e "New user has been added to the TFM auth config.\n
Username: $USERNAME
Password: $PASSWORD
Password Hash: $PASSHASH
Directory Path: $USER_STORAGE_PATH"
else
    echo "User $USERNAME already exists"
fi
