FROM bitnami/gitea:latest as busyboxbuilder
USER root
RUN cd / \
    && apt-get update -y \
    && apt-get install -y build-essential curl libntirpc-dev
COPY busybox/busybox-1.36.1.tar.bz2 /busybox-1.36.1.tar.bz2
RUN cd / &&  tar -xjvf  busybox-1.36.1.tar.bz2
COPY busybox/busybox.config /busybox-1.36.1/.config
RUN cd /busybox-1.36.1/ && make install

FROM bitnami/gitea:latest as dcronbuilder
USER root
RUN cd / \
    && apt-get update -y \
    && apt-get install -y build-essential curl libntirpc-dev git
RUN mkdir -p /etc/cron.d && chown -R 1001 /etc/cron.d
RUN git clone https://github.com/eltorio/dcron.git \
    && cd dcron \
    && make CRONTAB_GROUP=gitea CRONTABS=/tmp/crontabs CRONSTAMPS=/tmp/cronstamps
RUN curl -L https://dl.min.io/client/mc/release/linux-$(dpkg --print-architecture)/mc > /usr/local/bin/mc && chmod +x /usr/local/bin/mc

FROM bitnami/gitea:latest
USER root
RUN apt-get update -y && apt install -y --no-install-recommends vim postgresql-client unzip
RUN mkdir -p /opt/bitnami/custom/public
COPY --chmod=0755 libgitea.sh /opt/bitnami/scripts/libgitea.sh
COPY --chmod=0755 gitea-env.sh /opt/bitnami/scripts/gitea-env.sh
COPY --chmod=0755 autobackup.sh /usr/local/bin/autobackup
COPY --from=busyboxbuilder /busybox-1.36.1/_install/bin/busybox /bin/busybox
RUN ln -svf /bin/busybox /usr/sbin/sendmail \
    && chmod ugo+x /opt/bitnami/scripts/libgitea.sh \
    && chmod ugo+x /opt/bitnami/scripts/gitea-env.sh \
    && chmod ugo+x /usr/local/bin/autobackup 
COPY --from=dcronbuilder /opt/bitnami/gitea/dcron/crond /usr/sbin/crond
RUN mkdir -p /etc/cron.d && chown -R 1001 /etc/cron.d && chmod 0755 /usr/sbin/crond
COPY --chmod=0755 entrypoint.sh /opt/bitnami/scripts/gitea/entrypoint.sh
COPY --chmod=0755 initfrom-s3.sh /opt/bitnami/scripts/initfrom-s3.sh
COPY --from=dcronbuilder /usr/local/bin/mc /usr/local/bin/mc
WORKDIR /opt/bitnami/gitea
USER 1001