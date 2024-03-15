#!/bin/bash

until docker logs postgres_init_db | grep -c "english"; do
    sleep 0.5
done
