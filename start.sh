#!/bin/bash
# start.sh
#
# This script auto-registers a GitLab Runner using the new authentication token workflow.
# It optionally adds custom host entries to the runner’s configuration if EXTRA_HOSTS is set.
#
# Required environment variables:
#   - GITLAB_VHOST: GitLab hostname (e.g. gitlab.com or your custom host)
#   - RUNNER_TOKEN: Authentication token for runner registration
#
# Optional environment variables (with defaults):
#   - GITLAB_PROTOCOL (default: https)
#   - EXTRA_HOSTS     (comma-separated list of host:IP pairs, e.g.
#                      "example.com:93.184.216.34,test.local:127.0.0.1")
#
# The GitLab URL is constructed from GITLAB_PROTOCOL and GITLAB_VHOST.
#
# Debug output is printed for troubleshooting.
# Note: Remove or restrict debug output in production.

set -e

# Display GitLab Runner version.
echo "GitLab Runner version: $(gitlab-runner --version)"

# Validate required variables and set defaults for optional ones.
: "${GITLAB_VHOST:?GITLAB_VHOST is required}"
: "${RUNNER_TOKEN:?RUNNER_TOKEN is required}"
: "${GITLAB_PROTOCOL:=https}"

# Construct the GitLab URL.
GITLAB_URL="${GITLAB_PROTOCOL}://${GITLAB_VHOST}"

# Debug: Output configuration.
echo "DEBUG: GitLab Runner configuration:"
echo "  GITLAB_URL:   $GITLAB_URL"
if [[ -n "$EXTRA_HOSTS" ]]; then
    echo "  EXTRA_HOSTS:  $EXTRA_HOSTS"
fi
echo ""

# Check for existing registered runners.
# Temporarily disable exit-on-error for this command.
set +e
RUNNER_LIST_OUTPUT=$(gitlab-runner list 2>&1)
RUNNER_COUNT=$(echo "$RUNNER_LIST_OUTPUT" | grep -c "Executor")
set -e
echo "Number of runners registered: $RUNNER_COUNT"

if [[ "$RUNNER_COUNT" -eq 0 ]]; then
    echo "No runner registered. Performing auto-registration..."
    gitlab-runner register --non-interactive \
        --url "$GITLAB_URL" \
        --executor "docker" \
        --docker-image "alpine:latest" \
        --token "$RUNNER_TOKEN"
else
    echo "Runner already registered."
fi

# Path to the GitLab Runner configuration file.
CONFIG_FILE="/etc/gitlab-runner/config.toml"

# If the configuration file does not exist, create a minimal config file.
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Configuration file $CONFIG_FILE not found; creating default config."
    cat <<EOF > "$CONFIG_FILE"
concurrent = 1
check_interval = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "docker-runner"
  url = "$GITLAB_URL"
  token = "$RUNNER_TOKEN"
  executor = "docker"
  [runners.docker]
    image = "alpine:latest"
EOF
fi

# If EXTRA_HOSTS is set, add or update the extra_hosts entry in the [runners.docker] section.
if [[ -n "$EXTRA_HOSTS" ]]; then
    if grep -q "^\[runners\.docker\]" "$CONFIG_FILE"; then
        # Convert the comma-separated list to a TOML array.
        IFS=',' read -ra HOSTS_ARRAY <<< "$EXTRA_HOSTS"
        TOML_ARRAY="["
        first=true
        for host in "${HOSTS_ARRAY[@]}"; do
            if [ "$first" = true ]; then
                TOML_ARRAY="$TOML_ARRAY\"$host\""
                first=false
            else
                TOML_ARRAY="$TOML_ARRAY, \"$host\""
            fi
        done
        TOML_ARRAY="$TOML_ARRAY]"
        # Check if extra_hosts already exists.
        if grep -q "extra_hosts" "$CONFIG_FILE"; then
            echo "Updating existing extra_hosts entry in configuration file..."
            sed -i "s/^[[:space:]]*extra_hosts[[:space:]]*=.*/    extra_hosts = $TOML_ARRAY/" "$CONFIG_FILE"
        else
            echo "Inserting extra_hosts entry in configuration file..."
            sed -i "/^\[runners\.docker\]/a \    extra_hosts = $TOML_ARRAY" "$CONFIG_FILE"
        fi
        echo "EXTRA_HOSTS set to: $TOML_ARRAY"
    else
        echo "[runners.docker] section not found in $CONFIG_FILE; cannot add extra_hosts."
    fi
fi

# Start the GitLab Runner.
exec gitlab-runner run --user=gitlab-runner --working-directory=/home/gitlab-runner
