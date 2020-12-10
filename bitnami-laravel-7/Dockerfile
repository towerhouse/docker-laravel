FROM docker.io/bitnami/laravel:7-debian-10
COPY rootfs /
ENTRYPOINT [ "/app-entrypoint.sh" ]
CMD [ "php", "artisan", "serve", "--host=0.0.0.0", "--port=80" ]