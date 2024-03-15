#!/bin/bash

until docker logs postgres_init_db 2> /dev/null | grep -c "PostgreSQL init process complete"; do
    sleep 2
done
