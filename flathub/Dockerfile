
FROM nginx:stable-alpine

WORKDIR /usr/src/app

COPY nginx.conf /etc/nginx/nginx.conf

# Healthcheck so can check all the services of nginx
COPY healthcheck .


# Http port
EXPOSE 7777/tcp

HEALTHCHECK --interval=5s --timeout=2s --retries=3 --start-period=60s CMD [ "/usr/src/app/healthcheck" ]