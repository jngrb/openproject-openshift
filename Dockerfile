FROM openproject/community:11.0
# NOTE: the FROM line will be replaced by Openshift according to the BuildConfig
ARG DOCKER_PATH=./docker
RUN cd /app && ${DOCKER_PATH}/entrypoint.sh /bin/bash
ARG APP_PATH=/app
RUN chgrp -R 0 /home/app && \
    chmod -R g=u /home/app && \
    mkdir -p $APP_PATH/log $APP_PATH/tmp/pids $APP_PATH/files && \
    chgrp -R 0 $APP_PATH $APP_PATH/log $APP_PATH/tmp $APP_PATH/files $APP_PATH/public && \
    chmod -R g=u $APP_PATH $APP_PATH/log $APP_PATH/tmp $APP_PATH/files $APP_PATH/public && \
    chgrp 0 /etc/passwd && \
    chmod g=u /etc/passwd && \
    chgrp -R 0 /tmp/op_uploaded_files && \
    chmod -R g=u /tmp/op_uploaded_files
COPY uid_entrypoint.sh /app/docker/
ENTRYPOINT [ "/app/docker/uid_entrypoint.sh" ]
CMD [ "${DOCKER_PATH}/entrypoint.sh", "/bin/bash" ]
#USER app:app # UID==1000,GID=1000
# OpenShift needs the GID=0 setting
USER 1000:0
