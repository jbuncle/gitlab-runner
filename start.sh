#!/bin/bash
set -e

# Default to http protocol for GitLab host server
: "${GITLAB_PROTOCOL:-http}"


if [ "$GITLAB_CONCURRENT_RUNNERS" == "" ] ; then
    echo "Defaulting GITLAB_CONCURRENT_RUNNERS to 2"
    GITLAB_CONCURRENT_RUNNERS=2
fi
if [ "$GITLAB_LOCAL_HOST" == "" ] ; then
    echo "Defaulting GITLAB_LOCAL_HOST to $GITLAB_VHOST"
    GITLAB_LOCAL_HOST=$GITLAB_VHOST
fi

[ ! -z "$GITLAB_LOCAL_HOST" ] || (echo "Missing GITLAB_LOCAL_HOST" && exit)
[ ! -z "$GITLAB_REGISTRATION_TOKEN" ] || (echo "Missing GITLAB_REGISTRATION_TOKEN" && exit)


# Check if hostname is reachable
echo "Checking $GITLAB_VHOST is reachable (ping $GITLAB_VHOST)"
ping -q -c 1 $GITLAB_VHOST > /dev/null  || (echo "Can't reach host $GITLAB_VHOST" && exit)
        
echo "Connecting to $GITLAB_PROTOCOL://$GITLAB_VHOST"

# Wait until Gitlab is running
echo "Fetching status code for $GITLAB_PROTOCOL://$GITLAB_VHOST"
GITLAB_STATUSCODE="$(curl -L --write-out %{http_code} --silent --output /dev/null $GITLAB_PROTOCOL://$GITLAB_VHOST)"
while [ "$GITLAB_STATUSCODE" != "302" ]; do
    echo "Gitlab server not up yet, code is $GITLAB_STATUSCODE, sleeping..."
    sleep 5
    GITLAB_STATUSCODE="$(curl --write-out %{http_code} --silent --output /dev/null $GITLAB_PROTOCOL://$GITLAB_VHOST)"
done

echo "Gitlab server status is $(curl --write-out %{http_code} --silent --output /dev/null $GITLAB_PROTOCOL://$GITLAB_VHOST)"

if [ -f '/etc/gitlab-runner/config.toml' ] ; then
    gitlab-runner register --non-interactive \
     --url "$GITLAB_PROTOCOL://$GITLAB_VHOST/ci/" \
     --registration-token "$GITLAB_REGISTRATION_TOKEN" \
     --executor docker \
     --docker-image gitlab_runner \
     --docker-volumes /var/run/docker.sock:/var/run/docker.sock \
     --docker-privileged
else 
    echo "Runner previously registered"
fi

# Forward command on to original entrypoint
/usr/bin/dumb-init /entrypoint run "$@"
