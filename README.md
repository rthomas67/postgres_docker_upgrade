# Summary
Resources for upgrading a postgres database when postgres is running in a docker container.

# Overview
This repository contains a Dockerfile and a docker-compose.yml file that
assist in the process of running pg_upgrade in a docker environment.
* Dockerfile - builds a container image from the target version of postgres
and copies the binary files from the docker container image of the source 
version of postgres.  pg_upgrade requires both sets of binaries.
* docker-compose.yml contains two services that use the same image.
  * The "first" one runs the new version of postgres to init new db files.
  * The "second" one does NOT run postgres, but allows an attached shell (docker exec)
  to be used to run "pg_upgrade"

# Process
* **ATTENTION: DO NOT USE ANY OF THIS WITHOUT BACKING UP YOUR DB FIRST!!!**
  * There.  You've been warned.  If you proceed, and things go wrong, it's YOUR responsibility.

The process is mostly captured in the **rerunall.sh** shell script.
* Make a copy of .env_template as .env and modify its contents to match your environment.
* Shut down your old DB and copy all of its data files into a subdirectory named **postgres_data_old**
* Then Either...
  * Review what **rerunall.sh** does and then run it, or...
  * Read through it and run each of the commands one by one (assuming you want to understand better what's going on.)
* The script does the heavy lifting of setting up a docker environment where pg_upgrade can run, but 
the last step (actually running pg_upgrade) is a manual step.
  * The full pg_upgrade command line is baked into the docker image as an alias (**upgrade**) though, so it's not hard.
    * There's also an alias to pre-check the upgrade environment (**upgradecheck**)
* The script assumes the installed version of compose uses the **docker-compose** command,
so if this is used in and environment where it's **docker compose** (no dash) that will have
to be adjusted.

# Extra Stuff
* Default password encryption / authentication changed from md5 to SCRAM in postgres v14
  * If clients give an authentication error after upgrading, one quick remedy is to
  switch it back.
  * See: https://www.percona.com/blog/postgresql-14-and-recent-scram-authentication-changes-should-i-migrate-to-scram/
  * Fix: Edit the line (probably right at the bottom) in .../data/pg_hba.conf that determines the default encrypt/auth method
    * change: **host all all all scram-sha-256**
    *     to: **host all all all md5**

# Speedbumps
This section is just a highlight list of some of the things that made this a pain to get working.
* Starting the container as user postgres instead of root results in permissions errors
writing to the ".../datanew" mount, because when docker automatically creates it, root owns it.
  * ~~Fix: On the docker host: **sudo chown 999 ./postgres_data_upgraded**~~
  * This took care of itself with a change to allow the postgres container init script to
  actually initialize db files, fix permissions and ownership, etc.
* The very latest base container (bookworm) has updated to openssl3 but older versions of the
postgresql containers use openssl1 (e.g. 1.1.1), so when pg_upgrade attempts to run the older
postgres binary (for dump, etc.) in the newer container image, things go wrong.
  * Fix: Find images for both old and new postgres versions that derive from the same 
  base-container. e.g. 11.22-bookworm and 16.2-bookworm should be mostly compatible runtime
  overlays because they're both based on "bookworm" (the codename for that version of the
  Debian Linux distribution).  
* Copying older binaries into newer container images still fails because running
the old binary with -V to get the version reports that it can't execute because a file
is missing.
  * Fix: This was related to the fact that not all of the postgres stuff was in /usr/lib/postgresql/##
  and the Dockerfile was not yet copying the /usr/share/postgresql/## stuff too.  i.e. It's already fixed.
* Conflicting OID on the "main" database OID when restore command runs within pg_upgrade.
  * The issue is caused when the postgres container initializes a default db, with a name
  matching the username specified in POSTGRES_USER.  This results in the first assigned
  OID (16834) being associated with databases having different names in old and new, and
  pg_upgrade fails with a conflicting OID when it attempts to restore the "app" database.
  * Fix: If the POSTGRES_DB env var is present in the db init container, the first-initialized
  database (with OID 16834) will have that name instead of the POSTGRES_USER name.
  Migration from the old data (presumably set up the same way) ~~should then proceed without error~~
  because the OID and name will match on both sides.  Turns out this is moot anyway.  See the next item.
  * These pages don't necessarily explain what happens, but gave some hints to figure it out:
    * See: https://www.percona.com/blog/postgresql-upgrade-tricks-with-oid-columns-and-extensions/
    * See: https://forger.sitiv.fr/open-dsi/postgres/commit/aa010514
    * See: https://www.postgresql.org/message-id/CAASxf_Oj8cSJonwsWMtGyUTkK-EhmygW0HGTSXb1jCq_beAwkQ@mail.gmail.com
* Conflicting database in "new" cluster.  Seriously, pg_upgrade doesn't tolerate anything.  Without
all this babysitting, it's essentially useless.
  * Fix: Drop the initialized database in the "new" cluster before running pg_upgrade.
