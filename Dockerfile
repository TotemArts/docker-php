FROM php:8.3-fpm-alpine
COPY --chmod=0755 entrypoint.sh /entrypoint.sh

# ---- runtime dependencies ----
RUN apk add --no-cache \
    freetype \
    gmp \
    icu-libs \
    libjpeg-turbo \
    libpng \
    libxml2 \
    libzip \
    postgresql-libs \
    zip \
    unzip

# ---- build dependencies (PHP extensions) ----
RUN set -eux; \
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        linux-headers \
        freetype-dev \
        gmp-dev \
        icu-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libxml2-dev \
        libzip-dev \
        postgresql-dev; \
    \
    docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg; \
    \
    docker-php-ext-install -j"$(nproc)" \
        mysqli \
        pdo_mysql \
        pdo_pgsql \
        pgsql \
        gd \
        zip \
        intl \
        opcache \
        exif \
        gmp; \
    \
    pecl install redis; \
    docker-php-ext-enable redis; \
    \
    pecl install xdebug; \
    docker-php-ext-enable xdebug; \
    \
    docker-php-source delete; \
    rm -rf /tmp/pear ~/.pearrc; \
    apk del .build-deps

# ---- PHP configuration ----
RUN set -eux; \
    { \
        echo 'memory_limit=256M'; \
        echo 'upload_max_filesize=100M'; \
        echo 'post_max_size=100M'; \
        echo 'max_execution_time=300'; \
        echo 'opcache.enable=1'; \
    } > /usr/local/etc/php/conf.d/custom.ini; \
    printf '[www]\nrequest_terminate_timeout = 300\n' \
        > /usr/local/etc/php-fpm.d/zz-timeouts.conf

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm"]
