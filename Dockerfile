FROM openproject/community:10
ARG APP_PATH=/app
RUN chgrp -R 1000 /home/app && \
    chmod -R g=u /home/app && \
    mkdir -p $APP_PATH/log $APP_PATH/tmp/pids $APP_PATH/files && \
    chgrp -R 1000 $APP_PATH $APP_PATH/log $APP_PATH/tmp $APP_PATH/files $APP_PATH/public && \
    chmod -R g=u $APP_PATH $APP_PATH/log $APP_PATH/tmp $APP_PATH/files $APP_PATH/public && \
    chgrp 1000 /etc/passwd && \
    chmod g=u /etc/passwd
COPY uid_entrypoint.sh /app/docker/
RUN /app/docker/entrypoint.sh /bin/bash
ENTRYPOINT [ "/app/docker/uid_entrypoint.sh" ]
CMD [ "./docker/entrypoint.sh", "/bin/bash" ]
#USER app:app # UID==1000,GID=1000
USER 1000:1000
