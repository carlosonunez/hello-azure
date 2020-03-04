FROM ubuntu:19.04

# Install Ansible
RUN apt-get -y update && \
    apt-get -y install software-properties-common && \
    apt-add-repository --yes --update ppa:ansible/ansible && \
    apt-get -y install ansible

# Install SystemD since our app uses this upon starting up.
# Cribbed from: https://github.com/j8r/dockerfiles/blob/master/systemd/ubuntu/18.04.Dockerfile
ENV LC_ALL C
RUN apt-get update \
    && apt-get install -y systemd systemd-sysv \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN cd /lib/systemd/system/sysinit.target.wants/ \
    && ls | grep -v systemd-tmpfiles-setup | xargs rm -f $1

RUN rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/basic.target.wants/* \
    /lib/systemd/system/anaconda.target.wants/* \
    /lib/systemd/system/plymouth* \
    /lib/systemd/system/systemd-update-utmp*

VOLUME [ "/sys/fs/cgroup" ]

ENTRYPOINT [ "/sbin/init" ]
