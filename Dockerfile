FROM postgres:11.22-bookworm as oldbin

FROM postgres:16.2-bookworm
RUN apt-get update && apt-get -y install procps wget tree
#RUN apk update && apk add vim procps wget tree
# copy binaries from old version postgres docker container
RUN mkdir -p /usr/lib/postgresql/11 && mkdir -p /usr/share/postgresql/11
COPY --from=oldbin /usr/lib/postgresql/11 /usr/lib/postgresql/11
COPY --from=oldbin /usr/share/postgresql/11 /usr/share/postgresql/11

# Set up for "old data" volume
RUN mkdir -p /var/lib/postgresql/olddata && chown postgres /var/lib/postgresql/olddata
VOLUME /var/lib/postgresql/olddata

# pg_upgrade can't be run as root, so set the default user to postgres
# USER postgres
WORKDIR /var/lib/postgresql
# For convenience this creates an alias in the postgres home directory bash environment, with params already mapped to volumes, etc.
# Note: The official postgres container is set up so that the postgres user's home dir is /var/lib/postgresql, not /home/postgres.
RUN echo "alias upgrade='pg_upgrade -v -b /usr/lib/postgresql/11/bin -B /usr/lib/postgresql/16/bin -d /var/lib/postgresql/olddata -D /var/lib/postgresql/data'" >> /var/lib/postgresql/.bashrc
RUN echo "alias upgradecheck='pg_upgrade -v --check -b /usr/lib/postgresql/11/bin -B /usr/lib/postgresql/16/bin -d /var/lib/postgresql/olddata -D /var/lib/postgresql/data'" >> /var/lib/postgresql/.bashrc
USER postgres
