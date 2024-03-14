FROM postgres:11 as oldbin

FROM postgres:16.2-alpine3.18
#RUN apt-get update && apt-get -y install procps wget tree
RUN apk update && apk add procps wget tree
# copy binaries from old version postgres docker container
RUN mkdir -p /usr/lib/postgresql/11
RUN mkdir -p /var/lib/postgresql/datanew && chown postgres /var/lib/postgresql/datanew
VOLUME /var/lib/postgresql/datanew
COPY --from=oldbin /usr/lib/postgresql/11 /usr/lib/postgresql/11

# pg_upgrade can't be run as root, so set the default user to postgres
USER postgres
WORKDIR /var/lib/postgresql
# for convenience create an alias with params already mapped to volumes, etc.
RUN echo "alias upgrade='pg_upgrade -b /usr/lib/postgresql/11/bin -B /usr/lib/postgresql/16/bin -d /var/lib/postgresql/data -D /var/lib/postgresql/datanew'" >> ~/.bashrc

