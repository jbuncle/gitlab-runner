#!/bin/bash
set -e
set -u

# Default to http protocol for GitLab host server
: "${GITLAB_PROTOCOL:-http}"
: "${GITLAB_CONCURRENT_RUNNERS:-2}"
[ ! -z "$GITLAB_REGISTRATION_TOKEN" ] || (echo "Missing GITLAB_REGISTRATION_TOKEN" && exit)


counter=1 limit=3
until ping -q -c 1 $GITLAB_VHOST > /dev/null ; do
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
if [[ "$RUNNER_COUNT" == "0" ]] ; then
    # Generates /etc/gitlab-runner/config.toml
    gitlab-runner register --non-interactive \
     --url "$GITLAB_PROTOCOL://$GITLAB_VHOST/ci/" \
     --registration-token "$GITLAB_REGISTRATION_TOKEN" \
     --executor docker \
     --docker-image gitlab_runner \
     --docker-volumes /var/run/docker.sock:/var/run/docker.sock \
     --docker-volumes "/certs/client" \
     --docker-privileged
else 
    echo "Runner previously registered"
fi

# Forward command on to original entrypoint
/usr/bin/dumb-init /entrypoint run "$@"
