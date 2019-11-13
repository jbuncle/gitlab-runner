FROM gitlab/gitlab-runner:v10.3.0

ADD start.sh start.sh
RUN chmod +x start.sh

VOLUME /etc/gitlab-runner/

ENTRYPOINT ["./start.sh"]