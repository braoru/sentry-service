FROM cloudtrust-baseimage:f27

ARG sentry_service_git_tag
ARG sentry_wheel_release
ARG sentry_wheel_version
ARG config_git_tag
ARG config_repo


####################
# Sentry
####################

# add our user and group first to make sure their IDs get assigned consistently
RUN groupadd -r sentry && useradd -r -m -g sentry sentry

# Install nginx, python, pip and Sentry dependencies
RUN dnf -y install nginx haproxy redis python27 python-pip python-setuptools python2-devel wget gcc gcc-c++ gpg postgresql-devel postgresql-contrib python2-virtualenv \
    libffi-devel libjpeg-devel postgresql-libs libxml2-devel libxslt-devel libyaml-devel redhat-rpm-config ncurses-compat-libs dpkg make && \
    dnf clean all


WORKDIR /cloudtrust
RUN git clone git@github.com:cloudtrust/sentry-service.git && \    
    git clone ${config_repo} ./config

WORKDIR /cloudtrust/sentry-service
RUN git checkout ${sentry_service_git_tag}
WORKDIR /cloudtrust/config
RUN git checkout ${config_git_tag}

# Sane defaults for pip
ENV PIP_NO_CACHE_DIR off
ENV PIP_DISABLE_PIP_VERSION_CHECK on

##
## Sentry installation
##

WORKDIR /opt/sentry
RUN wget -O ./sentry-${sentry_wheel_version}-py27-none-any.whl ${sentry_wheel_release} && \
    virtualenv-2.7 . && \
    . bin/activate && \
    pip install sentry-${sentry_wheel_version}-py27-none-any.whl && \
    sentry --help

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
    install -v -o root -g root -m 644 deploy/common/etc/systemd/system/haproxy.service.d/limit.conf /etc/systemd/system/haproxy.service.d/limit.conf 


WORKDIR /cloudtrust/config
RUN install -v -d -m0755 -o sentry -g sentry /etc/sentry && \
    install -v -m755 -o root -g root deploy/etc/sentry/sentry.conf.py /etc/sentry/sentry.conf.py &&  \
    install -v -m755 -o root -g root deploy/etc/sentry/config.yml /etc/sentry/config.yml &&  \
    install -v -m755 -o root -g root deploy/etc/sentry/sentry.json /etc/sentry/sentry.json &&  \
    install -v -m755 -o root -g root deploy/etc/systemd/system/sentry_init.service /etc/systemd/system/sentry_init.service 
    

RUN systemctl enable sentry_init && \
    systemctl enable nginx.service && \
    systemctl enable redis.service && \
    systemctl enable sentry-web.service && \
    systemctl enable haproxy.service && \
    systemctl enable monit.service

EXPOSE 80

