#! /bin/bash

set -e

NAMESPACE=$(basename $(dirname $(pwd)))
NAME=$(basename `pwd`)
DOCKER_TAG=development

IMAGE_NAME=${NAMESPACE}/${NAME}:${DOCKER_TAG}

# Local machine build
build() {
    docker build -t $IMAGE_NAME .
}

run() {
   echo "Not supported"
}

push() {
    # Only pushes development tag
    echo "Pushing tag ${IMAGE_NAME}":development 
    docker push ${IMAGE_NAME}:development 
}

case $1 in
    "build")
        build
    ;;
    "run")
        run
    ;;
    "build-run")
        build
        run
    ;;
    "build-push")
        build
        push
    ;;
    *)
        echo "Specify 'build', or 'build-install'"
    ;;
esac
