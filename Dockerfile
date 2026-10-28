FROM php:8.3-fpm

COPY --chmod=0755 entrypoint.sh /entrypoint.sh

# ---- system deps (required for compiling PHP extensions) ----
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    libxml2-dev \
    zip \
    unzip \
    libgmp-dev \
    libpq-dev \
    lua5.1 \
    imagemagick \
    $PHPIZE_DEPS \
    && rm -rf /var/lib/apt/lists/*

# ---- configure GD properly (IPB uses image handling) ----
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg

# ---- install core extensions required by IPB 4.7 ----
RUN docker-php-ext-install -j$(nproc) \
    mysqli \
    pdo_mysql \
    pdo_pgsql \
    pgsql \
    gd \
    zip \
    intl \
    opcache \
    exif \
    gmp

# pecl.php.net intermittently returns 504s to CI runners, so retry downloads
RUN set -eux; \
    pecl_install() { \
        n=0; \
        until pecl install "$1"; do \
            n=$((n + 1)); \
            [ "$n" -lt 5 ] || return 1; \
            sleep $((n * 10)); \
        done; \
    }; \
    \
    pecl_install redis; \
    docker-php-ext-enable redis; \
    \
    # install xdebug but leave it off by default (configured in entrypoint)
    pecl_install xdebug; \
    docker-php-ext-enable xdebug; \
    docker-php-source delete

# ---- install core extensions required by IPB 4.7 ----
RUN echo "memory_limit=256M" >> /usr/local/etc/php/conf.d/custom.ini \
  && echo "upload_max_filesize=100M" >> /usr/local/etc/php/conf.d/custom.ini \
  && echo "post_max_size=100M" >> /usr/local/etc/php/conf.d/custom.ini \
  && echo "max_execution_time=300" >> /usr/local/etc/php/conf.d/custom.ini \
  && echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/custom.ini \
  && printf "\n[www]\nrequest_terminate_timeout = 300\n" >> /usr/local/etc/php-fpm.d/zz-timeouts.conf

# Run FPM workers as root when ROOTLESS=true. Rootless Docker maps container
# root to the host user, so files written to the bind mount (config.php,
# cache/, files/) stay owned by and editable by the host user.
# Dev only. Defaults to false, which keeps the image's www-data workers; CI
# publishes this variant as the <branch>-rootless tag.
ARG ROOTLESS=false
RUN if [ "$ROOTLESS" = "true" ]; then \
        printf '%s\n' '[www]' 'user = root' 'group = root' \
            > /usr/local/etc/php-fpm.d/zz-user.conf; \
    fi

ENTRYPOINT ["/entrypoint.sh"]
# --allow-to-run-as-root is only needed when the pool user is root
# (ROOTLESS=true) and is a no-op otherwise.
CMD ["php-fpm", "--allow-to-run-as-root"]
