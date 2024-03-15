#!/bin/bash

NEW_DATA_DIR=postgres_data_upgraded
OLD_DATA_DIR=postgres_data_old
DB_INIT_CONTAINER_NAME=postgres_init_db

docker-compose down --remove-orphans
# Uncomment this if the Dockerfile changed, otherwise no need to remove the image.
# docker image rm postgres_upgrade_image

# If it's the first time running, create the newdata directory referenced by the 
# docker-compose volume, or docker won't create the container.
mkdir -p ${NEW_DATA_DIR}
# Note: If the new data directory isn't cleared out, docker won't create the container
# Note: sudo won't work within a shell script for shell commands like rm, but chmod and chown work, so...
sudo chmod 777 -R ${NEW_DATA_DIR}
sudo chown $USER:$USER -R ${NEW_DATA_DIR}
pushd ${NEW_DATA_DIR}
rm -rf base pg_* postgresql.conf postgresql.auto.conf global PG_VERSION postmaster.opts postmaster.pid
popd

# Unless the user running docker can read/write the old data volume directory, 
# docker won't create the image/container, so temporarily make everything ugo+rwx
sudo chmod 777 -R ${OLD_DATA_DIR}
docker-compose --profile initnewdb up --no-start --build
# This initializes fresh db files
docker-compose --profile initnewdb start
echo "Waiting for postgres to finish initializing new db files."
until docker logs postgres_init_db 2> /dev/null | grep -c "PostgreSQL init process complete"; do
    sleep 2
done
sleep 2
# Drop the database created by the container auto-init to prevent pg_upgrade from
# failing with a conflict (database exists) error on CREATE DATABASE.
# Note: psql requires a connection db, postgres at the end, to run any command with -c
docker exec ${DB_INIT_CONTAINER_NAME} bash -c 'psql -c "drop database $POSTGRES_DB" postgres'

docker-compose --profile initnewdb stop
echo "Waiting for postgres init/setup container to stop"
# This won't work because the init process already shuts down the db earlier in the logs w/ the same message.
# docker-compose logs | sed '/database system is shut down$/ q'
sleep 5

# pg_upgrade complains and bails out if the data directory doesn't have permissions set for postgres
sudo chmod 700 ${OLD_DATA_DIR}

# Create the container w/o postgres running where upgrade will run
docker-compose --profile runupgrade up --no-start
docker-compose --profile runupgrade start

echo "Attaching to postgres_run_upgrade container.  Run upgradecheck and/or upgrade, then exit."
docker exec -ti postgres_run_upgrade /bin/bash
