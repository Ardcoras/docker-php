FROM debian:stable-slim
MAINTAINER Jyri-Petteri Paloposki <jyri-petteri.paloposki@citrus.fi>

# Let the container know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update
RUN apt-get -y upgrade
RUN apt-get install -y --no-install-recommends apt-utils
RUN apt-get update

# Basic Requirements
RUN apt-get -y install default-mysql-client nginx php-fpm php-mysql pwgen curl git unzip vim-nox

# Application Requirements
RUN apt-get -y install php-curl php-gd php-intl php-pear php-imagick php-imap php-mbstring php-memcache php-pspell php-tidy php-xmlrpc php-xml php-xsl php-ldap php-pgsql php-redis openssh-server varnish php-soap php-bcmath
RUN apt-get -y install php-dev libmcrypt-dev

RUN curl -o /tmp/composer.phar https://getcomposer.org/installer
RUN cd /tmp; php ./composer.phar
RUN chmod 0755 /tmp/composer.phar
RUN mv /tmp/composer.phar /usr/local/bin/composer
RUN cd /root; composer require drush/drush "<9"
ADD ./bashrc.sh /root/.bashrc
RUN chmod 0755 /root/.bashrc

# SMTP support
RUN apt-get -y install nullmailer mailutils && echo "mailhog smtp --port=1025" > /etc/nullmailer/remotes && \
  echo 'sendmail_path = "/usr/sbin/sendmail"' > /etc/php/7.4/fpm/conf.d/mail.ini && systemctl enable nullmailer

# nginx config
RUN sed -i -e"s/keepalive_timeout\s*65/keepalive_timeout 2/" /etc/nginx/nginx.conf
RUN sed -i -e"s/keepalive_timeout 2/keepalive_timeout 2;\n\tclient_max_body_size 100m/" /etc/nginx/nginx.conf
RUN echo "daemon off;" >> /etc/nginx/nginx.conf

# php-fpm config
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php/7.4/fpm/php.ini
RUN sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" /etc/php/7.4/fpm/php.ini
RUN sed -i -e "s/memory_limit\s*=\s*128M/memory_limit = 512M/g" /etc/php/7.4/fpm/php.ini
RUN sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" /etc/php/7.4/fpm/php.ini
RUN sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/7.4/fpm/php-fpm.conf
RUN sed -i -e "s/pid\s*=\s*\/run\/php\/php-fpm.pid/pid = \/run\/php-fpm.pid/g" /etc/php/7.4/fpm/php-fpm.conf
RUN sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php/7.4/fpm/pool.d/www.conf
RUN sed -i -e "s/listen\s*=\s*\/run\/php\/php-fpm.sock/listen = \/run\/php-fpm.sock/g" /etc/php/7.4/fpm/pool.d/www.conf
RUN find /etc/php/7.4/cli/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;

# nginx site conf
ADD ./drupal-site.conf /etc/nginx/sites-available/drupal.conf
ADD ./magento-site.conf /etc/nginx/sites-available/magento.conf
ADD ./livehelperchat-site.conf /etc/nginx/sites-available/livehelperchat.conf
ADD ./supervisor-stdout.patch /root/supervisor-stdout.patch

# Supervisor Config
RUN apt-get install python3-pip -y
RUN pip3 install supervisor
RUN pip3 install supervisor-stdout
RUN cat /usr/local/lib/python3.9/dist-packages/supervisor_stdout.py
RUN patch -i /root/supervisor-stdout.patch /usr/local/lib/python3.9/dist-packages/supervisor_stdout.py

ADD ./supervisord.conf /etc/supervisord.conf

# Initialization and Startup Script
ADD ./start.sh /start.sh
RUN chmod 755 /start.sh

# private expose
EXPOSE 80
EXPOSE 8080
EXPOSE 22

CMD ["/bin/bash", "/start.sh"]
