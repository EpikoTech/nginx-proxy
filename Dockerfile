FROM nginx:latest

# Instalar certbot y dependencias
RUN apt-get update && apt-get install -y \
    certbot \
    python3-certbot-nginx \
    cron \
    procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Script de renovación cada 12h
COPY renew.sh /renew.sh
RUN chmod +x /renew.sh

# Script de arranque: lanza cron + nginx
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]