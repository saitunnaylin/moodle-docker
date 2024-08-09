# Docker Container for Moodle
----------------------------------------------

This repository contains Docker image configuration aimed to provide a good starting point to install moodle using docker.

This repo aims to give a solution to generate docker images using officical moodle github.

## How to create a new image

- Inside a repository directory where Dockerfile exist, run below command:

```
docker build -t moodle:<TAG> .

```

## Usage Options

This image download and setup an moodle environment based on enironment variables that you supply in the docker command line or through docker-compose/swarm. Before you can use this container, you need to install and setup an database. After that, you'll need to provide the following information (through ENVIRONMENT variables):

 * MOODLE_DB_HOST: Address of Database Host;
 * MOODLE_DB_PORT: Port of Database;
 * MOODLE_DB_USER: Name of Database User;
 * MOODLE_DB_PASSWORD: Password of Database User;
 * MOODLE_DB_PREFIX: Name of Database Prefix;
 * MOODLE_DB_TYPE: Type of Database;
 * MOODLE_DB_NAME: Database Name;
 * MOODLE_REDIS_HOST: Address of Redis Host;
 * MOODLE_REDIS_PORT: Port of Database;
 * MOODLE_URL: wwwroot of moodle, must match with the server access fqdn;
 * MOODLE_SERVER_NAME: FQDN of the server;
 * MOODLE_ADMIN_USER: Name of Moodle User;
 * MOODLE_ADMIN_PASS: Password of Moodle User;

## Upgrade moodle

### Enable Maintenance
```
    docker exec -it <server_container> bash -c "sudo -u apache /usr/bin/php /var/www/html/moodle/admin/cli/maintenance.php --enable"
 ```   
### Pull from moodle
```
    docker exec -it <server_container> bash -c "cd /var/www/html/moodle && git branch --track MOODLE_<VERSION>_STABLE origin/MOODLE_<VERSION>_STABLE && git checkout MOODLE_<VERSION>_STABLE -f && git pull" 
```
### Upgrade moodle
 ```
    docker exec -it <server_container> bash -c "sudo -u apache /usr/bin/php /var/www/html/moodle/admin/cli/upgrade.php "
```
### Disable Maintenance
```
    docker exec -it <server_container> bash -c "sudo -u apache /usr/bin/php /var/www/html/moodle/admin/cli/maintenance.php --disable"
```

## Contributions

Are extremely welcome!