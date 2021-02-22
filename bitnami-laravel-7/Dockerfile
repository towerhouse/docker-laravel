FROM docker.io/bitnami/laravel:7-debian-10
RUN sudo apt-get -y update && sudo apt-get -y install apache2 libapache2-mod-php7.3 php7.3-mysql php7.3-curl php7.3-xml && sudo a2enmod rewrite
COPY rootfs /
COPY vhost /etc/apache2/sites-available/
COPY php_ini /opt/bitnami/php/lib/
ENTRYPOINT [ "/app-entrypoint.sh" ]
CMD ["sudo", "apachectl", "-D", "FOREGROUND"]
