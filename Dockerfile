FROM gitlab/gitlab-runner:v14.0.1

ADD start.sh start.sh
RUN chmod +x start.sh

VOLUME /etc/gitlab-runner/

ENTRYPOINT ["./start.sh"]
