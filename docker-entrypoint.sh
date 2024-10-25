#!/bin/bash

set -e

: ${MOODLE_SITE_FULLNAME:=Moodle}
: ${MOODLE_SITE_SHORTNAME:=Moodle}
: ${MOODLE_ADMIN_USER:=admin}
: ${MOODLE_ADMIN_PASS:=password}
: ${MOODLE_ADMIN_EMAIL:=admin@example.com}
: ${MOODLE_DB_TYPE:=mariadb}
: ${MOODLE_UPDATE:=false}

if [ -z "$MOODLE_DB_HOST" ]; then
	if [ -n "$MYSQL_PORT_3306_TCP_ADDR" ]; then
		MOODLE_DB_HOST=$MYSQL_PORT_3306_TCP_ADDR
	elif [ -n "$POSTGRES_PORT_5432_TCP_ADDR" ]; then
		MOODLE_DB_TYPE=pgsql
		MOODLE_DB_HOST=$POSTGRES_PORT_5432_TCP_ADDR
	elif [ -n "$DB_PORT_3306_TCP_ADDR" ]; then
		MOODLE_DB_HOST=$DB_PORT_3306_TCP_ADDR
	elif [ -n "$DB_PORT_5432_TCP_ADDR" ]; then
		MOODLE_DB_TYPE=pgsql
		MOODLE_DB_HOST=$DB_PORT_5432_TCP_ADDR
	else
		echo >&2 'error: missing MOODLE_DB_HOST environment variable'
		echo >&2 '	Did you forget to --link your database?'
		exit 1
	fi
fi

if [ -z "$MOODLE_DB_USER" ]; then
	if [ "$MOODLE_DB_TYPE" = "mysql" -o "$MOODLE_DB_TYPE" = "mariadb" ]; then
		echo >&2 'info: missing MOODLE_DB_USER environment variable, defaulting to "root"'
		MOODLE_DB_USER=root
	elif [ "$MOODLE_DB_TYPE" = "pgsql" ]; then
		echo >&2 'info: missing MOODLE_DB_USER environment variable, defaulting to "postgres"'
		MOODLE_DB_USER=postgres
	else
		echo >&2 'error: missing required MOODLE_DB_USER environment variable'
		exit 1
	fi
fi

if [ -z "$MOODLE_DB_PASSWORD" ]; then
	if [ -n "$MYSQL_ENV_MYSQL_ROOT_PASSWORD" ]; then
		MOODLE_DB_PASSWORD=$MYSQL_ENV_MYSQL_ROOT_PASSWORD
	elif [ -n "$POSTGRES_ENV_POSTGRES_PASSWORD" ]; then
		MOODLE_DB_PASSWORD=$POSTGRES_ENV_POSTGRES_PASSWORD
	elif [ -n "$DB_ENV_MYSQL_ROOT_PASSWORD" ]; then
		MOODLE_DB_PASSWORD=$DB_ENV_MYSQL_ROOT_PASSWORD
	elif [ -n "$DB_ENV_POSTGRES_PASSWORD" ]; then
		MOODLE_DB_PASSWORD=$DB_ENV_POSTGRES_PASSWORD
	else
		echo >&2 'error: missing required MOODLE_DB_PASSWORD environment variable'
		echo >&2 '	Did you forget to -e MOODLE_DB_PASSWORD=... ?'
		echo >&2
		echo >&2 '	(Also of interest might be MOODLE_DB_USER and MOODLE_DB_NAME)'
		exit 1
	fi
fi

: ${MOODLE_DB_NAME:=moodle}

if [ -z "$MOODLE_DB_PORT" ]; then
	if [ -n "$MYSQL_PORT_3306_TCP_PORT" ]; then
		MOODLE_DB_PORT=$MYSQL_PORT_3306_TCP_PORT
	elif [ -n "$POSTGRES_PORT_5432_TCP_PORT" ]; then
		MOODLE_DB_PORT=$POSTGRES_PORT_5432_TCP_PORT
	elif [ -n "$DB_PORT_3306_TCP_PORT" ]; then
		MOODLE_DB_PORT=$DB_PORT_3306_TCP_PORT
	elif [ -n "$DB_PORT_5432_TCP_PORT" ]; then
		MOODLE_DB_PORT=$DB_PORT_5432_TCP_PORT
	elif [ "$MOODLE_DB_TYPE" = "mysql" -o "$MOODLE_DB_TYPE" = "mariadb" ]; then
		MOODLE_DB_PORT="3306"
	elif [ "$MOODLE_DB_TYPE" = "pgsql" ]; then
		MOODLE_DB_PORT="5432"
	fi
fi

# Wait for the DB to come up
while [ "$(/bin/nc -w 1 "$MOODLE_DB_HOST" "$MOODLE_DB_PORT" < /dev/null > /dev/null; echo $?)" != 0 ]; do
    echo "Waiting for $MOODLE_DB_TYPE database to come up at $MOODLE_DB_HOST:$MOODLE_DB_PORT..."
    sleep 1
done
echo "Database is up and running."

export MOODLE_DB_TYPE MOODLE_DB_HOST MOODLE_DB_USER MOODLE_DB_PASSWORD MOODLE_DB_NAME

TERM=dumb php -- <<'EOPHP'
<?php
// database might not exist, so let's try creating it (just to be safe)

if (getenv('MOODLE_DB_TYPE') == 'mysql' || getenv('MOODLE_DB_TYPE') == 'mariadb') {

    $mysql = new mysqli(getenv('MOODLE_DB_HOST'), getenv('MOODLE_DB_USER'), getenv('MOODLE_DB_PASSWORD'), '', (int)getenv('MOODLE_DB_PORT'));

    if ($mysql->connect_error) {
        file_put_contents('php://stderr', 'MySQL Connection Error: (' . $mysql->connect_errno . ') ' . $mysql->connect_error . "\n");
        exit(1);
    }

    if (!$mysql->query('CREATE DATABASE IF NOT EXISTS `' . $mysql->real_escape_string(getenv('MOODLE_DB_NAME')) . '`')) {
        file_put_contents('php://stderr', 'MySQL "CREATE DATABASE" Error: ' . $mysql->error . "\n");
    }

    $mysql->close();
}
EOPHP

cd /var/www/html

: ${MOODLE_DATA:=/var/www/html/moodledata}
if [ ! -d "$MOODLE_DATA" ]; then
    echo "Created $MOODLE_DATA directory."
    mkdir -p $MOODLE_DATA /var/local/cache && \
    chown -R apache:apache $MOODLE_DATA && \
    chmod -R 777 $MOODLE_DATA /var/local/cache 
fi

# Initial config setup
CONF=/var/www/html/moodle/config.php

if [ -z ${MOODLE_SERVER_NAME} ]; then
	echo "No protocol provided. Assuming localhost"
	MOODLE_SERVER_NAME=localhost
fi	

if [ -z ${MOODLE_REDIS_HOST} ]; then
	echo "No Default Redis Host Provided. Assuming 'redis'"
	MOODLE_REDIS_HOST="redis"
fi

if [ -z ${MOODLE_REDIS_PORT} ]; then
	echo "No Default Redis Port Provided. Assuming '6379'"
		MOODLE_REDIS_PORT="6379"
fi

if [ ! -e $CONF ]; then
    echo "Preparing for inital config setup ....."
	mv /opt/moodle /var/www/html/moodle && touch $CONF

	cat <<-EOF >> $CONF
		<?php
		unset(\$CFG);
		global \$CFG;
		\$CFG = new stdClass();
		\$CFG->dbtype = "$MOODLE_DB_TYPE";
		\$CFG->dblibrary = "native";
		\$CFG->dbhost = "$MOODLE_DB_HOST";
		\$CFG->dbname = "$MOODLE_DB_NAME";
		\$CFG->dbuser = "$MOODLE_DB_USER";
		\$CFG->dbpass = "$MOODLE_DB_PASSWORD";
		\$CFG->prefix = "$MOODLE_DB_PREFIX";
		\$CFG->dboptions = array(
			'dbpersist' => 0,
			'dbsocket' => '',
			'dbport' => "$MOODLE_DB_PORT",
			'dbcollation' => 'utf8mb4_unicode_ci',
		);

		\$CFG->wwwroot = "$MOODLE_URL";
		\$CFG->dataroot = '$MOODLE_DATA';
		\$CFG->admin = 'admin';
	
		\$CFG->session_handler_class = '\core\session\redis';
		\$CFG->session_redis_host = '$MOODLE_REDIS_HOST';
		\$CFG->session_redis_port = $MOODLE_REDIS_PORT;

		\$CFG->directorypermissions = 0777;
		\define('CONTEXT_CACHE_MAX_SIZE', 7500);

		require_once(__DIR__ . '/lib/setup.php');
	
	EOF

	echo "ServerName $MOODLE_SERVER_NAME" >> /etc/httpd/conf/httpd.conf
 fi

# Install database if installed file doesn't exist
if [ ! -e "$MOODLE_DATA/installed" -a ! -f "$MOODLE_DATA/install.lock" ]; then
    echo "Moodle database is not initialized. Initializing..."
    touch $MOODLE_DATA/install.lock
    sudo -E -u apache php /var/www/html/moodle/admin/cli/install_database.php \
        --agree-license \
        --adminuser=$MOODLE_ADMIN_USER \
        --adminpass=$MOODLE_ADMIN_PASS \
        --adminemail=$MOODLE_ADMIN_EMAIL \
        --fullname="$MOODLE_SITE_FULLNAME" \
        --shortname="$MOODLE_SITE_SHORTNAME"
    if [ -n "$SMTP_HOST" ]; then
        sudo -E -u apache php /var/www/html/moodle/admin/cli/cfg.php --name=smtphosts --set=$SMTP_HOST
    fi
    if [ -n "$SMTP_USER" ]; then
        sudo -E -u apache php /var/www/html/moodle/admin/cli/cfg.php --name=smtpuser --set=$SMTP_USER
    fi
    if [ -n "$SMTP_PASS" ]; then
        sudo -E -u apache php /var/www/html/moodle/admin/cli/cfg.php --name=smtppass --set=$SMTP_PASS
    fi
    if [ -n "$SMTP_SECURITY" ]; then
        sudo -E -u apache php /var/www/html/moodle/admin/cli/cfg.php --name=smtpsecure --set=$SMTP_SECURITY
    fi
    if [ -n "$SMTP_AUTH_TYPE" ]; then
        sudo -E -u apache php /var/www/html/moodle/admin/cli/cfg.php --name=smtpauthtype --set=$SMTP_AUTH_TYPE
    fi
    if [ -n "$MOODLE_NOREPLY_ADDRESS" ]; then
        sudo -E -u apache php /var/www/html/moodle/admin/cli/cfg.php --name=noreplyaddress --set=$MOODLE_NOREPLY_ADDRESS
    fi

    touch $MOODLE_DATA/installed
    rm $MOODLE_DATA/install.lock
    echo "Done."
fi

/usr/sbin/php-fpm -D
while true; do $(sudo -u apache /usr/bin/php  /var/www/html/moodle/admin/cli/cron.php >/dev/null); done &

# Run additional init scripts
DIR=/docker-entrypoint.d

#if [[ -d "$DIR"  ]]
#then
#    /bin/run-parts --verbose "$DIR"
#fi

exec "$@"