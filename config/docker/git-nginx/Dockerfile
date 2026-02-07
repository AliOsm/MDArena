FROM alpine:3.21

RUN apk add --no-cache nginx git git-daemon fcgiwrap spawn-fcgi

COPY config/nginx/dev.conf /etc/nginx/http.d/default.conf
COPY config/docker/git-nginx/start.sh /start.sh
RUN chmod +x /start.sh

RUN mkdir -p /var/repos /run/nginx

EXPOSE 80

CMD ["/start.sh"]
