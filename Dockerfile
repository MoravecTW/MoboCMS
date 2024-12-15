# Multi-stage build
# Stage 1
# Run composer
FROM composer as composer
COPY ./composer.json /app
COPY ./composer.lock /app

RUN composer install --no-interaction --no-dev --optimize-autoloader

# Tidy up
# remove non-required vendor files
WORKDIR /app/vendor
RUN find -type d -name '.git' -exec rm -r {} + && \
    find -path ./twig/twig/lib/Twig -prune -type d -name 'Test' -exec rm -r {} + && \
    find -type d -name 'tests' -depth -exec rm -r {} + && \
    find -type d -name 'benchmarks' -depth -exec rm -r {} + && \
    find -type d -name 'smoketests' -depth -exec rm -r {} + && \
    find -type d -name 'demo' -depth -exec rm -r {} + && \
    find -type d -name 'doc' -depth -exec rm -r {} + && \
    find -type d -name 'docs' -depth -exec rm -r {} + && \
    find -type d -name 'examples' -depth -exec rm -r {} + && \
    find -type f -name 'phpunit.xml' -exec rm -r {} + && \
    find -type f -name '*.md' -exec rm -r {} +


# Stage 2
# Run webpack
FROM node:12 AS webpack
WORKDIR /app

# Copy package.json and the webpack config file
COPY webpack.config.js .
COPY package.json .
COPY package-lock.json .

# Install npm packages
RUN npm install

# Copy ui folder
COPY ./ui ./ui

# Copy modules source folder
COPY ./modules/src ./modules/src
COPY ./modules/vendor ./modules/vendor

# Build webpack
RUN npm run publish

# Stage 3
# Build the CMS container
FROM debian:bullseye-slim
MAINTAINER Xibo Signage <support@xibosignage.com>
LABEL org.opencontainers.image.authors="support@xibosignage.com"

# Install apache, PHP, and supplimentary programs.
RUN apt update && \
    apt install -y software-properties-common lsb-release ca-certificates curl && \
    rm -rf /var/lib/apt/lists/* && \
    ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime

# Add sury.org PHP Repository
RUN curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg && \
    sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'

RUN LC_ALL=C.UTF-8 DEBIAN_FRONTEND=noninteractive apt update && apt upgrade -y && apt install -y \
    tar \
    bash \
    curl \
    apache2 \
    libapache2-mod-xsendfile \
    netcat \
    iputils-ping \
    php8.2 \
    libapache2-mod-php8.2 \
    php8.2-zmq \
    php8.2-gd \
    php8.2-dom \
    php8.2-pdo \
    php8.2-zip \
    php8.2-mysql \
    php8.2-gettext \
    php8.2-soap \
    php8.2-iconv \
    php8.2-curl \
    php8.2-ctype \
    php8.2-fileinfo \
    php8.2-xml \
    php8.2-simplexml \
    php8.2-mbstring \
    php8.2-memcached \
    php8.2-phar \
    php8.2-opcache \
    php8.2-mongodb \
    tzdata \
    msmtp \
    openssl \
    cron \
    default-mysql-client \
    && dpkg-reconfigure --frontend noninteractive tzdata \
    && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --set php /usr/bin/php8.2

# Enable Apache module
RUN a2enmod rewrite \
    && a2enmod headers

# Add all necessary config files in one layer
ADD docker/ /

# Update the PHP.ini file
RUN sed -i "s/error_reporting = .*$/error_reporting = E_ERROR | E_WARNING | E_PARSE/" /etc/php/8.2/apache2/php.ini && \
    sed -i "s/session.gc_probability = .*$/session.gc_probability = 1/" /etc/php/8.2/apache2/php.ini && \
    sed -i "s/session.gc_divisor = .*$/session.gc_divisor = 100/" /etc/php/8.2/apache2/php.ini && \
    sed -i "s/allow_url_fopen = .*$/allow_url_fopen = Off/" /etc/php/8.2/apache2/php.ini && \
    sed -i "s/expose_php = .*$/expose_php = Off/" /etc/php/8.2/apache2/php.ini && \
    sed -i "s/error_reporting = .*$/error_reporting = E_ERROR | E_WARNING | E_PARSE/" /etc/php/8.2/cli/php.ini && \
    sed -i "s/session.gc_probability = .*$/session.gc_probability = 1/" /etc/php/8.2/cli/php.ini && \
    sed -i "s/session.gc_divisor = .*$/session.gc_divisor = 100/" /etc/php/8.2/cli/php.ini && \
    sed -i "s/allow_url_fopen = .*$/allow_url_fopen = Off/" /etc/php/8.2/cli/php.ini && \
    sed -i "s/expose_php = .*$/expose_php = Off/" /etc/php/8.2/cli/php.ini

# Capture the git commit for this build if we provide one
ARG GIT_COMMIT
ARG MYSQL_HOST
ARG MYSQL_USER
ARG MYSQL_PASSWORD
ARG MYSQL_DATABASE
ARG XMR_HOST
ARG CMS_SERVER_NAME
ARG CMS_SMTP_SERVER
ARG CMS_SMTP_USERNAME
ARG CMS_SMTP_PASSWORD
ARG CMS_SMTP_USE_TLS
ARG CMS_SMTP_USE_STARTTLS
ARG CMS_SMTP_REWRITE_DOMAIN
ARG CMS_SMTP_HOSTNAME
ARG CMS_SMTP_FROM_LINE_OVERRIDE
ARG CMS_SMTP_FROM
ARG CMS_USE_MEMCACHED
ARG CMS_PHP_POST_MAX_SIZE
ARG CMS_PHP_UPLOAD_MAX_FILESIZE
ARG CMS_PHP_MAX_EXECUTION_TIME
ARG CMS_PHP_SESSION_GC_MAXLIFETIME
ARG CMS_PHP_MEMORY_LIMIT
ARG CMS_QUICK_CHART_URL
ARG TZ
ARG MEMCACHED_HOST

# Setup persistent environment variables
ENV TZ=$TZ \
    CMS_DEV_MODE=false \
    INSTALL_TYPE=docker \
    XMR_HOST=$XMR_HOST \
    CMS_SERVER_NAME=$CMS_SERVER_NAME \
    MYSQL_HOST=$MYSQL_HOST \
    MYSQL_USER=$MYSQL_USER \
    MYSQL_PASSWORD=$MYSQL_PASSWORD \
    MYSQL_PORT=3306 \
    MYSQL_DATABASE=$MYSQL_DATABASE \
    MYSQL_BACKUP_ENABLED=true \
    MYSQL_ATTR_SSL_CA=none \
    MYSQL_ATTR_SSL_VERIFY_SERVER_CERT=true \
    CMS_SMTP_SERVER=$CMS_SMTP_SERVER \
    CMS_SMTP_USERNAME=$CMS_SMTP_USERNAME \
    CMS_SMTP_PASSWORD=$CMS_SMTP_PASSWORD \
    CMS_SMTP_USE_TLS=$CMS_SMTP_USE_TLS \
    CMS_SMTP_USE_STARTTLS=$CMS_SMTP_USE_STARTTLS \
    CMS_SMTP_REWRITE_DOMAIN=$CMS_SMTP_HOSTNAME \
    CMS_SMTP_HOSTNAME=$CMS_SMTP_HOSTNAME \
    CMS_SMTP_FROM_LINE_OVERRIDE=$CMS_SMTP_FROM_LINE_OVERRIDE \
    CMS_SMTP_FROM=$CMS_SMTP_FROM \
    CMS_ALIAS=none \
    CMS_PHP_SESSION_GC_MAXLIFETIME=$CMS_PHP_SESSION_GC_MAXLIFETIME \
    CMS_PHP_POST_MAX_SIZE=$CMS_PHP_POST_MAX_SIZE\
    CMS_PHP_UPLOAD_MAX_FILESIZE=$CMS_PHP_UPLOAD_MAX_FILESIZE \
    CMS_PHP_MAX_EXECUTION_TIME=$CMS_PHP_MAX_EXECUTION_TIME \
    CMS_PHP_MEMORY_LIMIT=$CMS_PHP_MEMORY_LIMIT \
    CMS_PHP_CLI_MAX_EXECUTION_TIME=0 \
    CMS_PHP_CLI_MEMORY_LIMIT=256M \
    CMS_PHP_COOKIE_SECURE=Off \
    CMS_PHP_COOKIE_HTTP_ONLY=On \
    CMS_PHP_COOKIE_SAMESITE=Lax \
    CMS_APACHE_START_SERVERS=2 \
    CMS_APACHE_MIN_SPARE_SERVERS=5 \
    CMS_APACHE_MAX_SPARE_SERVERS=10 \
    CMS_APACHE_MAX_REQUEST_WORKERS=60 \
    CMS_APACHE_MAX_CONNECTIONS_PER_CHILD=300 \
    CMS_APACHE_TIMEOUT=30 \
    CMS_APACHE_OPTIONS_INDEXES=false \
    CMS_QUICK_CHART_URL=$CMS_QUICK_CHART_URL \
    CMS_APACHE_SERVER_TOKENS=OS \
    CMS_APACHE_LOG_REQUEST_TIME=false \
    CMS_USE_MEMCACHED=$CMS_USE_MEMCACHED \
    MEMCACHED_HOST=$MEMCACHED_HOST \
    MEMCACHED_PORT=11211 \
    CMS_USAGE_REPORT=true \
    XTR_ENABLED=true \
    GIT_COMMIT=$GIT_COMMIT

# Expose port 80
EXPOSE 80

# Map the source files into /var/www/cms
RUN mkdir -p /var/www/cms

# Composer generated vendor files
COPY --from=composer /app /var/www/cms

# Copy dist built webpack app folder to web
COPY --from=webpack /app/web/dist /var/www/cms/web/dist

# Copy modules built webpack app folder to cms modules
COPY --from=webpack /app/modules /var/www/cms/modules

# All other files (.dockerignore excludes many things, but we tidy up the rest below)
COPY --chown=www-data:www-data . /var/www/cms

# OpenOOH specification
RUN mkdir /var/www/cms/openooh \
    && curl -o /var/www/cms/openooh/specification.json https://raw.githubusercontent.com/openooh/venue-taxonomy/main/specification.json

# Help Links
RUN curl -o /var/www/cms/help-links.yaml https://raw.githubusercontent.com/xibosignage/xibo-manual/master/help-links.yaml || true

# Git commit fallback
RUN echo $GIT_COMMIT > /var/www/cms/commit.sha

# Tidy up
RUN rm /var/www/cms/composer.* && \
    rm -r /var/www/cms/docker && \
    rm -r /var/www/cms/tests && \
    rm /var/www/cms/.dockerignore && \
    rm /var/www/cms/phpunit.xml && \
    rm /var/www/cms/package.json && \
    rm /var/www/cms/package-lock.json && \
    rm /var/www/cms/cypress.config.js && \
    rm -r /var/www/cms/cypress && \
    rm -r /var/www/cms/ui && \
    rm /var/www/cms/webpack.config.js && \
    rm /var/www/cms/lib/routes-cypress.php

# Map a volumes to this folder.
# Our CMS files, library, cache and backups will be in here.
RUN mkdir -p /var/www/cms/library/temp &&  \
    mkdir -p /var/www/backup && \
    mkdir -p /var/www/cms/cache && \
    mkdir -p /var/www/cms/web/userscripts && \
    chown -R www-data:www-data /var/www/cms && \
    chmod +x /entrypoint.sh /usr/local/bin/httpd-foreground /usr/local/bin/wait-for-command.sh \
    /etc/periodic/15min/cms-db-backup && \
    mkdir -p /run/apache2 && \
    ln -sf /usr/bin/msmtp /usr/sbin/sendmail && \
    chmod 777 /tmp

# Expose volume mount points
VOLUME /var/www/cms/library
VOLUME /var/www/cms/custom
VOLUME /var/www/cms/web/theme/custom
VOLUME /var/www/backup
VOLUME /var/www/cms/web/userscripts
VOLUME /var/www/cms/ca-certs

CMD ["/entrypoint.sh"]
