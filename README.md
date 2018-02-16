# sentry-service

## Installing sentry-service
```Bash
cd /cloudtrust
#Get the repo
git clone ssh://git@10.10.2.155:7999/cloudtrust/sentry-service.git

cd sentry-service

#install systemd unit file
install -v -o root -g root -m 644  deploy/common/etc/systemd/system/cloudtrust-sentry@.service /etc/systemd/system/cloudtrust-sentry@.service

mkdir build_context
cp dockerfiles/cloudtrust-sentry.dockerfile build_context/
cd build_context

#Build the dockerfile for DEV environment
docker build --build-arg branch=master -t cloudtrust-sentry:f27 -t cloudtrust-sentry:latest -f cloudtrust-sentry.dockerfile .

#create container 1
docker create -p 8080:80 --tmpfs /tmp --tmpfs /run -v /sys/fs/cgroup:/sys/fs/cgroup:ro --name sentry-1 cloudtrust-sentry

systemctl daemon-reload
#start container DEV1
systemctl start cloudtrust-sentry@1

# Init sentry
# The postgresql container must be running with ip 172.17.0.2 (configurable in haproxy.cfg). There must be a postgres user
# "cloudtrust" with password "cloudtrust" and a db "sentrydb". User "cloudtrust" must be superuser when executing 'sentry upgrade'
# (see https://github.com/getsentry/sentry/issues/6098)

# Configure postgresql db in container postgresql-dev1
docker exec -ti postgresql-dev1 /bin/bash
su postgres
psql
create user cloudtrust;
alter user cloudtrust with password 'cloudtrust';
alter user cloudtrust with superuser;
create database sentrydb;
grant all on database sentrydb to cloudtrust;
# exit postgres container

# Now we can init sentry
docker exec -ti sentry-dev1 /bin/bash -c 'sentry upgrade'



```
