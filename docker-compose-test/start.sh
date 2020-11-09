#!/bin/bash -e

docker-compose -f docker-compose.yml build

docker-compose -f docker-compose.yml up
