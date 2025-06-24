#!/bin/bash

set -Eeo pipefail

# Mandatory parameters
for param in MYSQL_USER_PASSWD
do
    if [ -z "${!param}" ]; then
        echo "Missing parameter in environement: $param"
    fi
done

# Optional parameters
MYSQL_HOST=${MYSQL_HOST:=db}
MYSQL_PORT=${MYSQL_PORT:=3306}
MYSQL_USER=${MYSQL_USER:=seafile}
MYSQL_USER_HOST=${MYSQL_USER_HOST:="%"}
CCNET_DB=${CCNET_DB:=ccnet_db}
SEAFILE_DB=${SEAFILE_DB:=seafile_db}
SEAHUB_DB=${SEAHUB_DB:=seahub_db}

# Runs official script
cd /opt/seafile
cp -f seafile-server-$SEAFILE_SERVER_VERSION/seahub/scripts/sqlite2mysql.* .
ln -s /shared/conf/ .
ln -s /shared/seafile-data/ .
ln -s /shared/sqlite ./ccnet
ln -s /shared/sqlite/seahub.db .
sed -i "s/python/python3/g" sqlite2mysql.sh
./sqlite2mysql.sh

# Generates all in one sql script
user=\'$MYSQL_USER\'@\'$MYSQL_USER_HOST\'
cat << EOF > restore.sql
create user $user identified by '$MYSQL_USER_PASSWD';

create database ccnet_db character set = 'utf8';
create database seafile_db character set = 'utf8';
create database seahub_db character set = 'utf8';

grant all privileges on $CCNET_DB.* to $user;
grant all privileges on $SEAFILE_DB.* to $user;
grant all privileges on $SEAHUB_DB.* to $user;

SET @@session.foreign_key_checks = 0;

use $CCNET_DB;
source /sqlite/ccnet-db.sql;

use $SEAFILE_DB;
source /sqlite/seafile-db.sql;

use $SEAHUB_DB;
source /sqlite/seahub-db.sql;
EOF

# Generates entrypoint
cat << EOF > /shared/sqlite/restore.sh
#!/bin/bash

/usr/bin/mysql -h db -u root -p -e "source /sqlite/restore.sql;"
EOF
chmod +x /shared/sqlite/restore.sh

# Exports to volume
mv *.sql /shared/sqlite/

# Writes configuration
CONFIG_DIR="/shared/conf"
CCNET_CONFIG_FILE="$CONFIG_DIR/ccnet.conf"
SEAHUB_CONFIG_FILE="$CONFIG_DIR/seahub_settings.py"
SEAFILE_CONFIG_FILE="$CONFIG_DIR/seafile.conf"

cat << EOF >> "$CCNET_CONFIG_FILE"
[Database]
ENGINE=mysql
HOST=$MYSQL_HOST
PORT=$MYSQL_PORT
USER=$MYSQL_USER
PASSWD=$MYSQL_USER_PASSWD
DB=$CCNET_DB
CONNECTION_CHARSET=utf8
EOF

cat << EOF >> "$SEAFILE_CONFIG_FILE"
[database]
type=mysql
host=$MYSQL_HOST
port=$MYSQL_PORT
user=$MYSQL_USER
password=$MYSQL_USER_PASSWD
db_name=$SEAFILE_DB
connection_charset=utf8 
EOF

cat << EOF >> "$SEAHUB_CONFIG_FILE"
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'USER' : '$MYSQL_USER',
        'PASSWORD' : '$MYSQL_USER_PASSWD',
        'NAME' : '$SEAHUB_DB',
        'HOST' : '$MYSQL_HOST',
        'PORT': '$MYSQL_PORT',
    }
}
EOF