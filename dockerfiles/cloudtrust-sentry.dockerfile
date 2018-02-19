FROM cloudtrust-baseimage:f27

ARG sentry_service_git_tag
WORKDIR /cloudtrust

####################
# Sentry
####################
# From https://github.com/getsentry/docker-sentry/blob/master/8.20/Dockerfile

# add our user and group first to make sure their IDs get assigned consistently
RUN groupadd -r sentry && useradd -r -m -g sentry sentry

# Intall monit, nginx, python, pip and Sentry dependencies
# redhat-rpm-config fix issue https://developer.fedoraproject.org/tech/languages/ruby/gems-installation.html
RUN dnf -y update && \
    dnf clean all && \
    dnf -y install monit nginx haproxy redis python27 python-pip python-setuptools python2-devel wget gcc gcc-c++ gpg postgresql-devel postgresql-contrib \
    libffi-devel libjpeg-devel postgresql-libs libxml2-devel libxslt-devel libyaml-devel redhat-rpm-config ncurses-compat-libs dpkg make && \
    dnf clean all && \
	git clone git@github.com:cloudtrust/sentry-service.git && \
	cd /cloudtrust/sentry-service && \
    git checkout ${sentry_service_git_tag}

# Sane defaults for pip
ENV PIP_NO_CACHE_DIR off
ENV PIP_DISABLE_PIP_VERSION_CHECK on

# grab gosu for easy step-down from root
ENV GOSU_VERSION 1.10
RUN set -x && \
    wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" && \
    wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" && \
    export GNUPGHOME="$(mktemp -d)" && \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && \
    gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu && \
    rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc && \
    chmod +x /usr/local/bin/gosu && \
    gosu nobody true

# grab tini for signal processing and zombie killing
ENV TINI_VERSION v0.14.0
RUN set -x && \
    wget -O /usr/local/bin/tini "https://github.com/krallin/tini/releases/download/$TINI_VERSION/tini" && \
    wget -O /usr/local/bin/tini.asc "https://github.com/krallin/tini/releases/download/$TINI_VERSION/tini.asc" && \
    export GNUPGHOME="$(mktemp -d)" && \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys 6380DC428747F6C393FEACA59A84159D7001A4E5 && \
    gpg --batch --verify /usr/local/bin/tini.asc /usr/local/bin/tini && \
    rm -r "$GNUPGHOME" /usr/local/bin/tini.asc && \
    chmod +x /usr/local/bin/tini && \
    tini -h

# Support for RabbitMQ
RUN set -x && \
    pip install librabbitmq==1.5.1 && \
    python -c 'import librabbitmq'

# Install Sentry    
ENV SENTRY_VERSION 8.21.0

RUN mkdir -p /usr/src/sentry && \
    wget -O /usr/src/sentry/sentry-${SENTRY_VERSION}-py27-none-any.whl "https://github.com/getsentry/sentry/releases/download/${SENTRY_VERSION}/sentry-${SENTRY_VERSION}-py27-none-any.whl" && \
    wget -O /usr/src/sentry/sentry-${SENTRY_VERSION}-py27-none-any.whl.asc "https://github.com/getsentry/sentry/releases/download/${SENTRY_VERSION}/sentry-${SENTRY_VERSION}-py27-none-any.whl.asc" && \
    wget -O /usr/src/sentry/sentry_plugins-${SENTRY_VERSION}-py2.py3-none-any.whl "https://github.com/getsentry/sentry/releases/download/${SENTRY_VERSION}/sentry_plugins-${SENTRY_VERSION}-py2.py3-none-any.whl" && \
    wget -O /usr/src/sentry/sentry_plugins-${SENTRY_VERSION}-py2.py3-none-any.whl.asc "https://github.com/getsentry/sentry/releases/download/${SENTRY_VERSION}/sentry_plugins-${SENTRY_VERSION}-py2.py3-none-any.whl.asc" && \
	export GNUPGHOME="$(mktemp -d)" && \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys D8749766A66DD714236A932C3B2D400CE5BBCA60 && \
    gpg --batch --verify /usr/src/sentry/sentry-${SENTRY_VERSION}-py27-none-any.whl.asc /usr/src/sentry/sentry-${SENTRY_VERSION}-py27-none-any.whl && \
    gpg --batch --verify /usr/src/sentry/sentry_plugins-${SENTRY_VERSION}-py2.py3-none-any.whl.asc /usr/src/sentry/sentry_plugins-${SENTRY_VERSION}-py2.py3-none-any.whl && \
    pip install /usr/src/sentry/sentry-${SENTRY_VERSION}-py27-none-any.whl /usr/src/sentry/sentry_plugins-${SENTRY_VERSION}-py2.py3-none-any.whl && \
    sentry --help && \
    sentry plugins list && \
    rm -r "$GNUPGHOME" /usr/src/sentry

ENV SENTRY_CONF=/etc/sentry \
    SENTRY_FILESTORE_DIR=/var/lib/sentry/files

RUN mkdir -p $SENTRY_CONF && mkdir -p $SENTRY_FILESTORE_DIR

# Configure Sentry, nginx, monit
RUN cd /cloudtrust/sentry-service && \
    install -v -m0644 deploy/common/etc/security/limits.d/* /etc/security/limits.d/ && \
# Install monit
    install -v -m0644 deploy/common/etc/monit.d/* /etc/monit.d/ && \    
# nginx setup
    install -v -m0644 -D deploy/common/etc/nginx/conf.d/* /etc/nginx/conf.d/ && \
    install -v -m0644 deploy/common/etc/nginx/nginx.conf /etc/nginx/nginx.conf && \
    install -v -m0644 deploy/common/etc/nginx/mime.types /etc/nginx/mime.types && \
    install -v -o root -g root -m 644 -d /etc/systemd/system/nginx.service.d && \
    install -v -o root -g root -m 644 deploy/common/etc/systemd/system/nginx.service.d/limit.conf /etc/systemd/system/nginx.service.d/limit.conf && \
# sentry setup
    install -v -m0755 -d /etc/sentry && \
    install -v -m0744 -d /run/sentry && \
    install -v -m0755 deploy/common/etc/sentry/* /etc/sentry && \
    install -v -o root -g root -m 644 -d /etc/systemd/system/sentry.service.d && \
    install -v -o root -g root -m 644 deploy/common/etc/systemd/system/sentry-web.service /etc/systemd/system/sentry-web.service && \
    install -v -o root -g root -m 644 deploy/common/etc/systemd/system/sentry-cron.service /etc/systemd/system/sentry-cron.service && \
    install -v -o root -g root -m 644 deploy/common/etc/systemd/system/sentry-worker.service /etc/systemd/system/sentry-worker.service && \
    install -v -o root -g root -m 644 deploy/common/etc/systemd/system/sentry.service.d/limit.conf /etc/systemd/system/sentry.service.d/limit.conf && \
# haproxy setup
    install -v -m0755 -d /etc/haproxy && \
    install -v -m0744 -d /run/haproxy && \
    install -v -m0755 deploy/common/etc/haproxy/* /etc/haproxy && \
    install -v -o root -g root -m 644 -d /etc/systemd/system/haproxy.service.d && \
    install -v -o root -g root -m 644 deploy/common/etc/systemd/system/haproxy.service.d/limit.conf /etc/systemd/system/haproxy.service.d/limit.conf && \
# enable services
    systemctl enable nginx.service && \
    systemctl enable redis.service && \
    systemctl enable sentry-web.service && \
    systemctl enable haproxy.service && \
    systemctl enable monit.service

VOLUME ["/var/lib/sentry/files"]

EXPOSE 80
