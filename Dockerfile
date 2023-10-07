FROM bitnami/gitea:latest
USER root
RUN apt-get update -y && apt install -y --no-install-recommends vim
RUN mkdir -p /opt/bitnami/custom/public
COPY --chmod=0755 libgitea.sh /opt/bitnami/scripts/libgitea.sh
COPY --chmod=0755 gitea-env.sh /opt/bitnami/scripts/gitea-env.sh
USER 1001