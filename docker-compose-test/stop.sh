#!/bin/bash

docker-compose -f docker-compose-initial.yml down

docker-compose -f docker-compose.yml down
