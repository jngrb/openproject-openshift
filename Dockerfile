FROM openproject/community:10
RUN /app/docker/entrypoint.sh /bin/bash
USER app
