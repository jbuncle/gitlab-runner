FROM gitlab/gitlab-runner:ubuntu-v15.11.0

RUN rm -f /etc/gitlab-runner/config.toml

# Copy the start script into the image.
COPY start.sh /start.sh

# Ensure the start script is executable.
RUN chmod +x /start.sh

# Use our start script as the entrypoint with bash.
ENTRYPOINT ["/bin/bash", "/start.sh"]
