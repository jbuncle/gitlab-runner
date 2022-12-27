#!/bin/bash
set -e
set -u

# Default to http protocol for GitLab host server
: "${GITLAB_PROTOCOL:-http}"
: "${DESCRIPTION:=Runner}"
: "${GITLAB_CONCURRENT_RUNNERS:-2}"
[ ! -z "$GITLAB_REGISTRATION_TOKEN" ] || (echo "Missing GITLAB_REGISTRATION_TOKEN" && exit)


getremotestatus() {
    curl -sL -w "%{http_code}\\n" "$GITLAB_VHOST" -o /dev/null
}

counter=1 limit=3
until [ $(getremotestatus) = 200 ] ; do
    echo "$GITLAB_VHOST not accessible" 
    [ "$counter" -lt "$limit" ] || (echo "Reached limit when trying to access ${GITLAB_VHOST}"; exit 1)
    sleep 3
    counter=`expr $counter + 1`
done

echo "Connecting to $GITLAB_PROTOCOL://$GITLAB_VHOST"

# Wait until Gitlab is running
echo "Fetching status code for $GITLAB_PROTOCOL://$GITLAB_VHOST"
counter=1 limit=10
until [ "$(curl -L --write-out %{http_code} --silent --output /dev/null $GITLAB_PROTOCOL://$GITLAB_VHOST)" == 200 ] > /dev/null ; do 
    [ "$counter" -lt "$limit" ] || (echo "Reached limit waiting for $GITLAB_PROTOCOL://$GITLAB_VHOST to be accessible"; exit 1)
    echo "Gitlab server not up, code is $GITLAB_STATUSCODE, sleeping..." 
    sleep 3
    counter=`expr $counter + 1`
done

echo "Gitlab server status is $(curl --write-out %{http_code} --silent --output /dev/null $GITLAB_PROTOCOL://$GITLAB_VHOST)"


RUNNER_COUNT=$(gitlab-runner list 2>&1 | grep Executor | wc -l)

echo "Number of runners registered: $RUNNER_COUNT"
if [[ "${RUNNER_COUNT}" == "0" ]] ; then
    # Generates /etc/gitlab-runner/config.toml
    gitlab-runner register --non-interactive \
     --url "${GITLAB_PROTOCOL}://${GITLAB_VHOST}/ci/" \
     --registration-token "${GITLAB_REGISTRATION_TOKEN}" \
     --executor docker \
     --cache-dir /var/cache/gitlab-runner \
     --description "${DESCRIPTION}" \
     --docker-image "docker:20.10.16" \
     --docker-privileged \
     --docker-volumes "/certs/client"
    #  --docker-volumes /var/run/docker.sock:/var/run/docker.sock \

else 
    echo "Runner previously registered"
fi

# Forward command on to original entrypoint
/usr/bin/dumb-init /entrypoint run "$@"
