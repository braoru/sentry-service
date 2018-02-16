FROM cloudtrust-sentry:alpha-1.0

ARG environment
ARG branch
ARG customer_repository

WORKDIR /cloudtrust
# Get customer config
RUN git clone ${customer_repository} ./config &&  \
	cd ./config &&  \
    git checkout ${branch}

# Setup Customer http-router related config
############################################

WORKDIR /cloudtrust/${customer_repository_name}
RUN install -v -m755 -o root -g root deploy/${environment}/etc/sentry/sentry.conf.py /etc/sentry/sentry.conf.py &&  \
    install -v -m755 -o root -g root deploy/${environment}/etc/sentry/config.yml /etc/sentry/config.yml &&  \
    install -v -m755 -o root -g root deploy/${environment}/etc/sentry/sentry.json /etc/sentry/sentry.json &&  \
    install -v -m755 -o root -g root deploy/${environment}/etc/systemd/system/sentry_init.service /etc/systemd/system/sentry_init.service &&  \
    systemctl enable sentry_init 
