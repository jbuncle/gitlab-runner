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

echo "Connecting to $GITLAB_PROTOCOL://$GITLAB_VHOST"


# Wait until Gitlab is running
GITLAB_STATUSCODE="$(curl --write-out %{http_code} --silent --output /dev/null $GITLAB_PROTOCOL://$GITLAB_VHOST)"
while [ "$GITLAB_STATUSCODE" != "302" ]; do
    echo "Gitlab server not up yet, code is $GITLAB_STATUSCODE, sleeping..."
    sleep 5
    GITLAB_STATUSCODE="$(curl --write-out %{http_code} --silent --output /dev/null $GITLAB_PROTOCOL://$GITLAB_VHOST)"
done

echo "Gitlab server status is $(curl --write-out %{http_code} --silent --output /dev/null $GITLAB_PROTOCOL://$GITLAB_VHOST)"


# Build config.toml
(
cat <<EOF
concurrent = ${GITLAB_CONCURRENT_RUNNERS}
check_interval = 0
[[runners]]
  name = "gitlab-runner"
  url = "${GITLAB_PROTOCOL}://${GITLAB_VHOST}/ci/"
  token = "${GITLAB_REGISTRATION_TOKEN}"
  executor = "docker"
  privileged = true
  cache_dir = "cache"
  [runners.docker]
    privileged = true
    tls_verify = false
    image = "docker"
    disable_cache = false
    volumes = ["/var/run/docker.sock:/var/run/docker.sock", "/cache"]
  [runners.cache]
    Insecure = true
EOF
) > /etc/gitlab-runner/config.toml

echo "Created file"
cat /etc/gitlab-runner/config.toml


# TODO: check if already registered
gitlab-runner register --non-interactive \
     --url "$GITLAB_PROTOCOL://$GITLAB_VHOST/ci/" \
     --registration-token "$GITLAB_REGISTRATION_TOKEN" \
     --executor docker \
     --docker-image gitlab_runner \
     --docker-volumes /var/run/docker.sock:/var/run/docker.sock \
     --docker-privileged

# Forward command on to original entrypoint
/usr/bin/dumb-init /entrypoint run "$@"
