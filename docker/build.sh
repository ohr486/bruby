#!/bin/bash

echo buildtest bruby ...

P=`dirname $(pwd)`

docker rmi `docker images | grep bruby | awk '{print $3}'`
cd $P
docker build -f ./docker/Dockerfile -t bruby .
