########### FROM https://github.com/joostvdg/apache2-openidc-docker
########### MIT License
FROM debian:bullseye

## ENV
ENV DEBIAN_FRONTEND noninteractive
ENV LAST_CHANGE 202109302000
ENV DEFAULT_SITE_LOC=/etc/apache2/sites-available/ \
    DEFAULT_SITE=000-default.conf \
    OIDC_PASS_PHRASE=""\ 
    OIDC_METADATA_URL=""\
    OIDC_CLIENT_ID=""\
    OIDC_CLIENT_SECRET=""\
    OIDC_REDIRECT_URL=""\
    OIDC_REMOTE_USER_CLAIM="preferred_username"
ENV TINI_VERSION v0.19.0
EXPOSE 80
## ENV

## PREPARE TINI
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
## PREPARE TINI

## PREPARE APACHE2 
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates apache2 libapache2-mod-auth-openidc && rm -rf /var/lib/apt/lists/*

ADD 000-default.conf ${DEFAULT_SITE_LOC}/${DEFAULT_SITE}
RUN a2enmod proxy \
    && a2enmod proxy_http \
    && a2enmod ssl \
    && a2enmod rewrite \
    && a2enmod auth_openidc \
    && service apache2 stop
## PREPARE APACHE2 

## RUNTIME PREPARATION
COPY httpd-foreground.sh /usr/local/bin/
RUN chmod +x  /usr/local/bin/httpd-foreground.sh
CMD /usr/local/bin/httpd-foreground.sh
ENTRYPOINT ["/tini", "-vv","-g", "--"]
## RUNTIME PREPARATION

# Invalid Mutex directory in argument file:/var/lock/apache2
RUN mkdir -p /var/lock/apache2
# AH00100: apache2: could not log pid to file /var/run/apache2/apache2.pid
RUN mkdir -p /var/run/apache2
RUN a2enmod headers

########### Openshift addendum
########### Same License as the rest of this repository
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
