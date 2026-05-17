#!/bin/bash
# ==========================================================
# Script: renew.sh
# Renueva certificados vencidos y recarga nginx si hubo cambios
# ==========================================================

LOG="/var/log/certbot-renew.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔍 Verificando certificados..." >> $LOG

certbot renew \
  --webroot -w /var/www/html \
  --quiet \
  --deploy-hook "nginx -s reload && echo '[$(date '+%Y-%m-%d %H:%M:%S')] ✅ nginx recargado tras renovación' >> $LOG"

if [ $? -eq 0 ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Revisión completada sin errores." >> $LOG
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Error en certbot renew. Revisa los logs." >> $LOG
fi