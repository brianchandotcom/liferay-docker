FROM pypy:3.7-slim

ARG LABEL_BUILD_DATE
ARG LABEL_NAME
ARG LABEL_VCS_REF
ARG LABEL_VCS_URL
ARG LABEL_VERSION

ADD --chown=root:root https://raw.githubusercontent.com/liferay/beautysh/master/src/beautysh.py /usr/local/bin/beautysh.py
ADD --chown=root:root https://raw.githubusercontent.com/liferay/beautysh/master/src/beautysh.sh /usr/local/bin/beautysh.sh

RUN chmod +x /usr/local/bin/beautysh.sh && \
    chmod +x /usr/local/bin/beautysh.py && \
    pip install colorama

LABEL org.label-schema.build-date="${LABEL_BUILD_DATE}"
LABEL org.label-schema.name="${LABEL_NAME}"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.vcs-ref="${LABEL_VCS_REF}"
LABEL org.label-schema.vcs-url="${LABEL_VCS_URL}"
LABEL org.label-schema.vendor="Liferay, Inc."
LABEL org.label-schema.version="${LABEL_VERSION}"

ENTRYPOINT [ "beautysh.sh" ]