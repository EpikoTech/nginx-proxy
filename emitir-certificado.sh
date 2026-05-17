#!/bin/bash
# ==========================================================
# Script: emitir-certificado.sh
# Genera certificado SSL dentro del contenedor nginx-proxy
# Autor: Epiko Tecnologia
# ==========================================================

DOMINIO=$1
EMAIL=$2

if [ -z "$DOMINIO" ] || [ -z "$EMAIL" ]; then
  echo "❌ Uso: ./emitir-certificado.sh dominio.pe admin@dominio.pe"
  exit 1
fi

CONF_DIR="./conf.d"
HTML_DIR="./html"
LETS_DIR="./letsencrypt"
CONF_FINAL="$CONF_DIR/${DOMINIO}.conf"
CONF_BACKUP="$CONF_DIR/${DOMINIO}.conf.bak"
CONF_TEMP="$CONF_DIR/${DOMINIO}-temp.conf"

# ==========================
# ⚙️ 1. Verificar que nginx-proxy esté corriendo
# ==========================
echo "🔍 Verificando que nginx-proxy esté activo..."
if ! docker ps --format '{{.Names}}' | grep -q "^nginx-proxy$"; then
  echo "❌ El contenedor nginx-proxy no está corriendo."
  echo "💡 Tip: Ejecuta 'docker compose up -d nginx-proxy' primero."
  exit 1
fi

# ==========================
# ⚙️ 2. Verificar si el certificado ya existe
# ==========================
if [ -f "$LETS_DIR/live/${DOMINIO}/fullchain.pem" ]; then
  echo "✅ El certificado para $DOMINIO ya existe. Nada que hacer."
  echo "💡 La renovación automática ocurre cada 12h si vence en menos de 30 días."
  exit 0
fi

# ==========================
# ⚙️ 3. Preparar directorios y conf temporal
# ==========================
mkdir -p "$CONF_DIR" "$HTML_DIR" "$LETS_DIR"
mkdir -p "$HTML_DIR/.well-known/acme-challenge"

if [ -f "$CONF_FINAL" ]; then
  echo "📦 Haciendo backup de ${DOMINIO}.conf → ${DOMINIO}.conf.bak ..."
  mv "$CONF_FINAL" "$CONF_BACKUP"
fi

echo "📄 Creando configuración HTTP temporal para $DOMINIO ..."
cat > "$CONF_TEMP" <<EOF
server {
  listen 80;
  server_name ${DOMINIO} www.${DOMINIO} api.${DOMINIO};
  root /var/www/html;

  location /.well-known/acme-challenge/ {
    allow all;
    try_files \$uri =404;
  }

  location / {
    return 200 "Servidor temporal listo para Certbot\n";
  }
}
EOF

echo "🔄 Recargando nginx-proxy con conf temporal..."
docker exec nginx-proxy nginx -t && docker exec nginx-proxy nginx -s reload
if [ $? -ne 0 ]; then
  echo "❌ Error al recargar nginx-proxy."
  [ -f "$CONF_BACKUP" ] && mv "$CONF_BACKUP" "$CONF_FINAL"
  rm -f "$CONF_TEMP"
  exit 1
fi

sleep 3

# ==========================
# 🔐 4. Ejecutar Certbot DENTRO del contenedor nginx-proxy
# ==========================
echo "🔐 Solicitando certificado SSL para ${DOMINIO} ..."
docker exec nginx-proxy certbot certonly --webroot \
  -w /var/www/html \
  -d "${DOMINIO}" \
  -d "www.${DOMINIO}" \
  -d "api.${DOMINIO}" \
  --agree-tos -m "${EMAIL}" --no-eff-email

if [ $? -eq 0 ]; then
  echo "✅ Certificado generado correctamente para ${DOMINIO}."

  rm -f "$CONF_TEMP"

  if [ -f "$CONF_BACKUP" ]; then
    echo "↩️  Restaurando ${DOMINIO}.conf desde backup..."
    mv "$CONF_BACKUP" "$CONF_FINAL"
    echo "🔄 Recargando nginx-proxy con conf SSL definitiva..."
    docker exec nginx-proxy nginx -t && docker exec nginx-proxy nginx -s reload
    if [ $? -eq 0 ]; then
      echo "✅ nginx-proxy corriendo con SSL activo para $DOMINIO"
    else
      echo "⚠️  Revisa manualmente $CONF_FINAL"
    fi
  else
    echo ""
    echo "📋 Próximos pasos:"
    echo "   1. Crea $CONF_FINAL con tu config SSL"
    echo "   2. Ejecuta: docker exec nginx-proxy nginx -s reload"
    echo ""
    echo "   Certificados en: ./letsencrypt/live/${DOMINIO}/"
    echo "     - fullchain.pem"
    echo "     - privkey.pem"
  fi

else
  echo "❌ Error al generar el certificado."
  echo "💡 Tip: Verifica que $DOMINIO apunte a la IP de este servidor."
  echo "💡 Tip: Verifica que el puerto 80 esté abierto en el firewall."

  rm -f "$CONF_TEMP"
  if [ -f "$CONF_BACKUP" ]; then
    echo "↩️  Restaurando backup tras el error..."
    mv "$CONF_BACKUP" "$CONF_FINAL"
    docker exec nginx-proxy nginx -s reload
  fi

  exit 1
fi