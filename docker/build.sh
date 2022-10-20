#!/bin/bash

echo buildtest bruby ...

docker rmi `docker images | grep bruby | awk '{print $3}'`
docker build -t bruby ..
