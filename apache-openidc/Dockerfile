FROM caladreas/apache2-openidc-docker:0.2.0

RUN chgrp -R 0 /var/log/apache2 && \
    chmod -R g=u /var/log/apache2 && \
    chgrp -R 0 /var/lock/apache2 && \
    chmod -R g=u /var/lock/apache2 && \
    chgrp -R 0 /var/run/apache2 && \
    chmod -R g=u /var/run/apache2 && \
    chgrp -R 0 /etc/apache2 && \
    chmod -R g=u /etc/apache2

ADD ports.conf /etc/apache2/
ADD 000-default.conf ${DEFAULT_SITE_LOC}/${DEFAULT_SITE}

COPY httpd-foreground.sh /usr/local/bin/
RUN chmod +x  /usr/local/bin/httpd-foreground.sh
