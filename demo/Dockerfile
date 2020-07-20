FROM liferay/dxp:7.3.10-ep4

ENV TAG="7.3.3-ga4"

WORKDIR /opt/liferay/deploy

COPY --chown=liferay:liferay script/download_jars.sh /temp/

RUN /temp/download_jars.sh

WORKDIR /opt/liferay