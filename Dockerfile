FROM python:3.8-alpine
MAINTAINER HPS Cloud Services
LABEL maintainer="HPS Cloud Services"

# References for Dockerfile creation
# https://github.com/puckel/docker-airflow
# https://github.com/brunocfnba/docker-airflow/blob/master/Dockerfile-alpine
# https://github.com/astronomer/ap-airflow/blob/master/1.10.12/alpine3.10/Dockerfile
# https://github.com/jfloff/alpine-python/blob/master/2.7/Dockerfile
# https://hub.docker.com/r/jfloff/alpine-python/dockerfile/

# If you want to use console programs that create text-based user interfaces (e.g. clear, less, top, vim, nano, …)
# the TERM environment variable (↑) must be set.
ENV TERM linux

# Airflow
ARG AIRFLOW_VERSION=1.10.12
ARG AIRFLOW_USER_HOME=/usr/local/airflow
ARG AIRFLOW_DEPS=""
ARG PYTHON_DEPS=""
ENV AIRFLOW_HOME=${AIRFLOW_USER_HOME}

ARG AIRFLOW_USER="airflow"
ARG AIRFLOW_GROUP="airflow"
ENV AIRFLOW_USER=${AIRFLOW_USER}
ENV AIRFLOW_GROUP=${AIRFLOW_GROUP}

ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LC_CTYPE en_US.UTF-8
ENV LC_MESSAGES en_US.UTF-8

RUN addgroup -S ${AIRFLOW_GROUP} \
	&& adduser -S -G ${AIRFLOW_GROUP} ${AIRFLOW_USER}

ENV PYTHON_BUILD_PACKAGES="\
       build-base \
       gcc \
       cyrus-sasl-dev \
       freetype-dev \
       krb5-dev \
       libffi-dev \
       libxml2-dev \
       libxslt-dev \
       linux-headers \
       python3-dev \
       musl-dev \
       postgresql-dev \
       mariadb-dev \
       tzdata \
       git \
      "
ENV PACKAGES="\
        bash \
        make \
        ca-certificates \
        cyrus-sasl \
        py3-pip \
        py3-setuptools \
        py3-wheel \
        rsync \
        git \
        curl \
        libpq \
        krb5-libs \
        tini \
    "

RUN set -ex \
    && apk update upgrade -f \
    && apk add --no-cache --virtual .build-deps $PYTHON_BUILD_PACKAGES || \
        (sed -i -e 's/dl-cdn/dl-4/g' /etc/apk/repositories && apk add --no-cache --virtual .build-deps $PYTHON_BUILD_PACKAGES) \
    && apk add --no-cache $PACKAGES || \
        (sed -i -e 's/dl-cdn/dl-4/g' /etc/apk/repositories && apk add --no-cache $PACKAGES) \
    && apk add --upgrade \
       openssl \
       openssh \
       && update-ca-certificates \
       && cp /usr/share/zoneinfo/UTC /etc/localtime \
       && pip3 install --no-cache-dir --upgrade pip setuptools wheel \
       && pip install --no-cache-dir pytz \
       && pip install --no-cache-dir pyOpenSSL \
       && pip install --no-cache-dir ndg-httpsclient \
       && pip install --no-cache-dir pyasn1 \
       && pip install --no-cache-dir Jinja2 \
       && pip install --no-cache-dir cryptography \
       && pip install --no-cache-dir flask-bcrypt \
       && pip install --no-cache-dir psycopg2 \
       && pip install --no-cache-dir redis \
       && pip install --no-cache-dir apache-airflow[crypto,celery,postgres,hive,jdbc,mysql,ssh${AIRFLOW_DEPS:+,}${AIRFLOW_DEPS}]==${AIRFLOW_VERSION} \
       && if [ -n "${PYTHON_DEPS}" ]; then pip install ${PYTHON_DEPS}; fi \
       && apk del --no-cache --purge .build-deps mariadb-dev build-base \
       && rm -rf \
             /var/cache/apk/* \
             /tmp/* \
             /var/tmp/* \
             /usr/share/man \
             /usr/share/doc

# Switch to AIRFLOW_HOME
WORKDIR ${AIRFLOW_HOME}

# Create logs directory so we can own it when we mount volumes
RUN mkdir -p ${AIRFLOW_HOME}/logs

# Copy entrypoint to path
COPY script/entrypoint.sh ${AIRFLOW_HOME}/entrypoint.sh

# Copy airflow.cfg from local to conatiner path
COPY config/airflow.cfg ${AIRFLOW_HOME}/airflow.cfg

# Copy "cron" scripts for clean logs. By default 15 days of log would be retained and we can customize too.
COPY script/clean-airflow-logs.sh ${AIRFLOW_HOME}/clean-airflow-logs.sh

# Ensure our user has ownership to AIRFLOW_HOME
RUN chown -R ${AIRFLOW_USER}:${AIRFLOW_GROUP} ${AIRFLOW_HOME}

RUN pwd
RUN ls -ltr ${AIRFLOW_HOME}

# Expose all airflow ports
EXPOSE 8080 5555 8793

RUN chmod +x ./entrypoint.sh

RUN chmod +x ./clean-airflow-logs.sh

# Run airflow with minimal init
ENTRYPOINT ["tini", "--", "./entrypoint.sh"]

# Invoke the airflow to start the webserver in background
CMD ["webserver"]

