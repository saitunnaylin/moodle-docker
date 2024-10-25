# Use AlmaLinux as the base image
FROM almalinux:8.10

# Set environment variables
ENV MOODLE_VERSION=MOODLE_404_STABLE
ENV UPLOAD_MAX_FILESIZE=200M
ENV PHP_MEMORY_LIMIT=512M
ENV PHP_MAX_EXECUTION_TIME=300
ENV PHP_MAX_INPUT_VARS=6000

# Install necessary packages
RUN dnf -y update && \
    dnf -y install epel-release && dnf -y install https://rpms.remirepo.net/enterprise/remi-release-8.rpm && \
    dnf -y module install php:remi-8.2 && \
    dnf -y install \
    netcat \
    git \
    php \
    php-cli \
    php-fpm \
    php-gd \
    php-intl \
    php-xmlrpc \
    php-soap \
    php-xml \
    php-mbstring \
    php-zip \
    php-opcache \
    php-pdo \
    php-mysqli \
    php-redis \
    php-pecl-redis \
    php-json \
    php-curl \
    php-ctype \
    php-dom \
    php-simplexml \
    mariadb \
    httpd \
    sudo \
    mod_ssl \
    unzip && \
    dnf clean all && dnf -y update

# Create moodle directory
RUN mkdir -p /opt/moodle

# Clone the Moodle repository
RUN git clone -b $MOODLE_VERSION https://github.com/moodle/moodle.git /opt/moodle

# Set permission for them and plugin
RUN chmod -R 777 /opt/moodle/theme && \
    chmod -R 777 /opt/moodle/mod

# Create SSL Cert
RUN mkdir -p /etc/pki/tls/private && chmod 700 /etc/pki/tls/private

# Generate Self Sign Certificate
RUN openssl req -subj '/CN=localhost/O=Moodle/C=US' -new -newkey rsa:4096 -sha256 -days 3650 -nodes -x509 -keyout /etc/pki/tls/private/localhost.key -out /etc/pki/tls/certs/localhost.crt

# Create php-fpm directory
RUN mkdir -p /run/php-fpm

# Create docker entry folder
RUN mkdir /docker-entrypoint.d

# Copy docker entrypoint
COPY docker-entrypoint.sh /docker-entrypoint.sh

# Copy php.ini
COPY php.ini /etc/php.ini

# Configure Apache
COPY moodle.conf /etc/httpd/conf.d/moodle.conf

# Volume
VOLUME /var

# Expose port 80
EXPOSE 80 443

# Entrypoint script
ENTRYPOINT ["/docker-entrypoint.sh"]

# Start Apache in foreground
CMD ["/usr/sbin/httpd", "-D", "FOREGROUND"]
