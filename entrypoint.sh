#!/bin/bash
# ==========================================================
# Script: entrypoint.sh
# Arranca cron y nginx juntos dentro del contenedor
# ==========================================================

# Registrar el cron job cada 12h
echo "0 */12 * * * /renew.sh" > /etc/cron.d/certbot-renew
chmod 0644 /etc/cron.d/certbot-renew
crontab /etc/cron.d/certbot-renew

echo "🕐 Cron de renovación SSL registrado (cada 12h)"

# Arrancar cron en background
service cron start

echo "🚀 Arrancando nginx..."
# nginx en foreground para que el contenedor no muera
nginx -g "daemon off;"