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

Username=$1
Password=$2
Passhash=""
Algo="PASSWORD_DEFAULT"

BaseDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
StorageDir="storage"
StoragePath="${BaseDir}/${StorageDir}"

if [[ -z $Username || -z $Password ]]; then
    echo -e "Username or Password is required.\nCommand: adduser.sh username password"
    exit 1
fi

# Update config #

UserExist=$(grep -qwE "${Username}" config/auth.php && echo True || echo False)

if [[ "${UserExist}" == False ]]; then

    if [[ -n $(which php) ]]; then
        PHP_CMD="echo password_hash(\"${Password}\", ${Algo});"
        Passhash=$(php -r "${PHP_CMD}")
    fi

    # add new user auth
    sed -i "/^];/i \    '${Username}'\ =>\ '${Passhash}'," config/auth.php

    # add new user directory
    UserStorageDir="${StorageDir}/${Username}"
    UserStoragePath="${StoragePath}/${Username}"

    if [[ ! -d $UserStoragePath ]]; then
        mkdir $UserStoragePath
    fi

    sed -i "/^];/i \    '${Username}'\ =>\ '${UserStorageDir}'," config/directories.php

    echo -e "New user added to the auth users.\n
Username: $Username
Password: $Password
Password Hash: $Passhash
Hash Algorithm: $Algo
Directory Path: $UserStoragePath"

else
    echo "User $Username already exists"
fi
