# Summary
Resources for upgrading a postgres database when postgres is running in a docker container.

# Overview
This repository contains a Dockerfile and a docker-compose.yml file that
assist in the process of running pg_upgrade in a docker environment.
* Dockerfile - builds a container image from the target version of postgres
and copies the binary files from the docker container image of the source 
version of postgres.  pg_admin requires both sets of pg_files.
  * Note: All of the binary files from the source version image are copied,
  which isn't optimal, but the image/container is temporary and that is
  easier than trying to filter only the pg_* files.

# Process
1. Run **docker compose up --no-start --build**
  * **docker-compose** on some platforms
2. Run **docker compose start**
  * Note: The docker-compose.yml file overrides the image entrypoint and **DOES NOT RUN** postgres.
  * This container will run, doing essentially nothing on its own, until explicitly stopped.
3. Run **docker exec -ti postgres_upgrade /bin/bash**
  * This attaches a shell to the running "upgrade" container.
4. Within the container shell, run **upgrade**
  * This is an alias that provides the CLI switches for old and new binaries and config/data.
5. Exit the docker container shell.
6. Stop and delete the upgrade container **docker compose down**
7. Stop the application-postgres container (and probably also the application container)
8. Move postgres volume directories active-pg-volume-path-->temp-keep, new-->active-pg-volume-path
9. Update the image version in application-postgres container used by the application (docker-compose)

# Speedbumps
* Starting the container as user postgres instead of root results in permissions errors
writing to the ".../datanew" mount, because when docker automatically creates it, root owns it.
  * Fix: On the docker host: **sudo chown 999 ./postgres_data_upgraded**
* The very latest base container (bookworm) has updated to openssl3 but older versions of the
postgresql binaries use openssl1 (e.g. 1.1.1), so when pg_upgrade attempts to run the older
version of postgres -V, everything stops there.
  * Fix: Use a slightly older base-container (bullseye) version of the postgres image.
* Copying older binaries into newer container images still fails because running
the old binary with -V to get the version reports that it can't execute because a file
is missing.
  * Fix: ???? setup and do smaller hops between versions, with the same base container
  overlapping ????
* Conflicting OID on the "main" database OID when restore command runs within pg_upgrade.
  * The issue is caused when the postgres container initializes a default db, with a name
  matching the username specified in POSTGRES_USER.  This results in the first assigned
  OID (16834) being associated with databases having different names in old and new, and
  pg_upgrade fails with a conflicting OID when it attempts to restore the "app" database.
  * Fix: If the POSTGRES_DB env var is present in the db init container, the first-initialized
  database (with OID 16834) will have that name instead of the POSTGRES_USER name.
  Migration from the old data (presumably set up the same way) will then proceed without error
  because the OID and name will match on both sides.
  * These pages don't necessarily explain what happens, but gave some hints to figure it out:
    * See: https://www.percona.com/blog/postgresql-upgrade-tricks-with-oid-columns-and-extensions/
    * See: https://forger.sitiv.fr/open-dsi/postgres/commit/aa010514
    * See: https://www.postgresql.org/message-id/CAASxf_Oj8cSJonwsWMtGyUTkK-EhmygW0HGTSXb1jCq_beAwkQ@mail.gmail.com
* Conflicting database in "new" cluster.  Seriously, pg_upgrade doesn't tolerate anything.  Without
all this babysitting, it's essentially useless.
  * Fix: Drop the initialized database in the "new" cluster before running pg_upgrade.
