FROM python:3.5
MAINTAINER Benjamin Hutchins <ben@hutchins.co>

ENV DEBIAN_FRONTEND noninteractive
ENV APP_ROOT=/usr/src
WORKDIR ${APP_ROOT}

# Version of Nginx to install
ENV NGINX_VERSION "1.9.7-1~jessie"

RUN apt-key adv \
  --keyserver keyserver.ubuntu.com \
  --recv-keys 379CE192D401AB61

RUN echo "deb http://nginx.org/packages/mainline/debian/ jessie nginx" >> /etc/apt/sources.list

RUN set -x;
RUN apt-get update 
RUN wget "http://ftp.se.debian.org/debian/pool/main/o/openssl/libssl1.0.0_1.0.2l-1~bpo8+1_amd64.deb"
RUN dpkg -i libssl1.0.0_1.0.2l-1~bpo8+1_amd64.deb
RUN apt-get install -y --no-install-recommends locales
RUN apt-get install -y --no-install-recommends gettext
RUN apt-get install -y --no-install-recommends ca-certificates
RUN apt-get install -y --no-install-recommends vim
RUN apt-get install -y --no-install-recommends --allow-unauthenticated nginx=${NGINX_VERSION}
RUN rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8 && dpkg-reconfigure locales

COPY taiga-back /usr/src/taiga-back
COPY taiga-front-dist/ /usr/src/taiga-front-dist
COPY docker-settings.py /usr/src/taiga-back/settings/docker.py
COPY conf/locale.gen /etc/locale.gen
COPY conf/nginx/nginx.conf /etc/nginx/nginx.conf
# To get taiga-events working, uncomment this and comment next line
#COPY conf/nginx/taiga-events.conf /etc/nginx/conf.d/default.conf
COPY conf/nginx/taiga.conf /etc/nginx/conf.d/default.conf
COPY conf/nginx/ssl.conf /etc/nginx/ssl.conf
COPY conf/nginx/taiga-events.conf /etc/nginx/taiga-events.conf

## Install Slack extension
RUN LC_ALL=C pip install --no-cache-dir taiga-contrib-slack
RUN mkdir -p /usr/src/taiga-front-dist/dist/plugins/slack/
RUN SLACK_VERSION=$(pip show taiga-contrib-slack | awk '/^Version: /{print $2}') && \
    echo "taiga-contrib-slack version: $SLACK_VERSION" && \
    curl https://raw.githubusercontent.com/taigaio/taiga-contrib-slack/$SLACK_VERSION/front/dist/slack.js -o /usr/src/taiga-front-dist/dist/plugins/slack/slack.js && \
    curl https://raw.githubusercontent.com/taigaio/taiga-contrib-slack/$SLACK_VERSION/front/dist/slack.json -o /usr/src/taiga-front-dist/dist/plugins/slack/slack.json

# Setup symbolic links for configuration files
RUN mkdir -p /taiga
COPY conf/taiga/local.py /taiga/local.py
COPY conf/taiga/conf.json /taiga/conf.json
RUN ln -s /taiga/local.py /usr/src/taiga-back/settings/local.py
RUN ln -s /taiga/conf.json /usr/src/taiga-front-dist/dist/conf.json

# Backwards compatibility
RUN mkdir -p /usr/src/taiga-front-dist/dist/js/
RUN ln -s /taiga/conf.json /usr/src/taiga-front-dist/dist/js/conf.json

WORKDIR /usr/src/taiga-back

# specify LANG to ensure python installs locals properly
# fixes benhutchins/docker-taiga-example#4
# ref benhutchins/docker-taiga#15
ENV LANG C

RUN pip install --no-cache-dir -r requirements.txt

RUN echo "LANG=en_US.UTF-8" > /etc/default/locale
RUN echo "LC_TYPE=en_US.UTF-8" > /etc/default/locale
RUN echo "LC_MESSAGES=POSIX" >> /etc/default/locale
RUN echo "LANGUAGE=en" >> /etc/default/locale

ENV LANG en_US.UTF-8
ENV LC_TYPE en_US.UTF-8

RUN locale-gen en_US en_US.UTF-8
RUN dpkg-reconfigure locales

ENV TAIGA_SSL False
ENV TAIGA_SSL_BY_REVERSE_PROXY False
ENV TAIGA_ENABLE_EMAIL False
ENV TAIGA_HOSTNAME localhost
ENV TAIGA_SECRET_KEY "!!!REPLACE-ME-j1598u1J^U*(y251u98u51u5981urf98u2o5uvoiiuzhlit3)!!!"

# Uncoment this in order to get taiga-events working
#ENV RABBIT_PORT_5672_TCP_ADDR "amqp://guest:guest@rabbit:5672//"

RUN python manage.py collectstatic --noinput

RUN locale -a

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 8080 443

VOLUME /usr/src/taiga-back/media

COPY checkdb.py /checkdb.py

COPY docker-entrypoint.sh /docker-entrypoint.sh

## OPTIONAL: If you want to store database backups every day
ENV PGPASSWORD="password"

RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main" >>  /etc/apt/sources.list.d/pgdg.list
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN apt-get update 
RUN apt-get install -y --no-install-recommends postgresql-client rsync

ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.1.8/supercronic-linux-amd64 \
    SUPERCRONIC=supercronic-linux-amd64 \
    SUPERCRONIC_SHA1SUM=be43e64c45acd6ec4fce5831e03759c89676a0ea

RUN curl -fsSLO "$SUPERCRONIC_URL" \
 && echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c - \
 && chmod +x "$SUPERCRONIC" \
 && mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}" \
 && ln -s "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic

# Create a non-root user
# Use it only for OpenShift image
ENV HOME=${APP_ROOT}
COPY bin/ ${APP_ROOT}/bin/
COPY cron/ ${APP_ROOT}/cron/
RUN chmod -R u+x ${APP_ROOT}/bin && \
    chmod -R u+x ${APP_ROOT}/cron && \
    chgrp -R 0 ${APP_ROOT} && \
    chmod -R g=u ${APP_ROOT} /etc/passwd && \
    chmod -R g=u /var/log/nginx /var/cache/nginx /var/run /etc/nginx /taiga /usr/src/taiga-back/media/

USER 10001

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["sh","-c", "/usr/src/bin/run_cmd"]
#CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
