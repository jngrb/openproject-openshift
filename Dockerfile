FROM openproject/community:10
RUN /app/docker/entrypoint.sh /bin/bash
ARG APP_PATH=/app
RUN chgrp -R 0 /home/app && \
    chmod -R g=u /home/app && \
    mkdir -p $APP_PATH/log $APP_PATH/tmp/pids $APP_PATH/files && \
    chgrp -R 0 $APP_PATH $APP_PATH/log $APP_PATH/tmp $APP_PATH/files $APP_PATH/public && \
    chmod -R g=u $APP_PATH $APP_PATH/log $APP_PATH/tmp $APP_PATH/files $APP_PATH/public && \
    chgrp 0 /etc/passwd && \
    chmod g=u /etc/passwd
COPY uid_entrypoint.sh /app/docker/
ENTRYPOINT [ "/app/docker/uid_entrypoint.sh" ]
CMD [ "./docker/entrypoint.sh", "/bin/bash" ]
#USER app:app # UID==1000,GID=1000
# OpenShift needs the GID=0 setting
USER 1000:0
