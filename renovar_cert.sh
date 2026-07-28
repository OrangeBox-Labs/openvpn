#!/bin/bash

# autor: Felipe Román froman@orangebox.cl
# Descripción: script para renovar los certificados de clientes o site-to-site de OpenVPN
# y también corrige los permisos para que la plantilla de zabbix para chequear los certificados de OpenVPN pueda leerlos correctamente. (disponible en nuestro github https://github.com/OrangeBox-Labs/Zabbix )

# Directorios base
EASY_RSA_DIR="/etc/openvpn/server/easy-rsa/3"
PKI_DIR="$EASY_RSA_DIR/pki"
ISSUED_DIR="$PKI_DIR/issued"
PRIVATE_DIR="$PKI_DIR/private"
OUTPUT_DIR="/var/www/html/vpn"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Verificar si el directorio OUTPUT existe
mkdir -p "$OUTPUT_DIR"

# Función para mostrar uso
mostrar_uso() {
  echo "=========================================="
  echo "  RENOVAR CERTIFICADO VPN"
  echo "  OrangeBox"
  echo "=========================================="
  echo ""
  echo "Uso: $0 <nombre_cliente>"
  echo ""
  echo "Ejemplos:"
  echo "  $0 felipe"
  echo "  $0 froman"
  echo "  $0 proveedor_01"
  echo ""
  echo "Para renovar TODOS los certificados:"
  echo "  $0 all"
  echo "=========================================="
  exit 1
}

# Función para verificar y corregir permisos
fix_permissions() {
  local client="$1"

  # Cambiar propietario de los archivos del cliente
  if [ -f "$ISSUED_DIR/$client.crt" ]; then
    chown root:zabbix-openvpn "$ISSUED_DIR/$client.crt"
    chmod 644 "$ISSUED_DIR/$client.crt"
    echo -e "${GREEN}✓${NC} $ISSUED_DIR/$client.crt -> root:zabbix-openvpn (644)"
  fi

  if [ -f "$PRIVATE_DIR/$client.key" ]; then
    chown root:zabbix-openvpn "$PRIVATE_DIR/$client.key"
    chmod 640 "$PRIVATE_DIR/$client.key"
    echo -e "${GREEN}✓${NC} $PRIVATE_DIR/$client.key -> root:zabbix-openvpn (640)"
  fi
}

# Función para generar el archivo .ovpn con certificados embebidos
generar_ovpn() {
  local client="$1"
  local output_file="$OUTPUT_DIR/$client.ovpn"

  echo "Generando archivo $client.ovpn con certificados embebidos..."

  # Verificar que todos los archivos necesarios existen
  if [ ! -f "$ISSUED_DIR/$client.crt" ]; then
    echo -e "${RED}ERROR:${NC} Certificado $client.crt no encontrado"
    return 1
  fi

  if [ ! -f "$PRIVATE_DIR/$client.key" ]; then
    echo -e "${RED}ERROR:${NC} Clave $client.key no encontrada"
    return 1
  fi

  if [ ! -f "$PKI_DIR/ca.crt" ]; then
    echo -e "${RED}ERROR:${NC} CA certificate no encontrado"
    return 1
  fi

  if [ ! -f "/etc/openvpn/server/ta.key" ]; then
    echo -e "${RED}ERROR:${NC} tls-crypt key no encontrada"
    return 1
  fi

  # Generar archivo .ovpn
  cat >"$output_file" <<EOF
client
dev tun
proto udp

remote vpn.orangebox.cl 1194  # Reemplazar por tu dirección 

nobind

persist-key
persist-tun

remote-cert-tls server

data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305

auth SHA256

verb 3

<ca>
$(cat "$PKI_DIR/ca.crt")
</ca>

<cert>
$(cat "$ISSUED_DIR/$client.crt")
</cert>

<key>
$(cat "$PRIVATE_DIR/$client.key")
</key>

<tls-crypt>
$(cat "/etc/openvpn/server/ta.key")
</tls-crypt>
EOF

  if [ "$?" -eq 0 ]; then
    # Cambiar propietario y permisos
    chown root:zabbix-openvpn "$output_file"
    chmod 644 "$output_file"
    echo -e "${GREEN}✓${NC} Archivo generado: $output_file"
    echo "  Tamaño: $(du -h "$output_file" | cut -f1)"
    return 0
  else
    echo -e "${RED}ERROR:${NC} No se pudo generar $output_file"
    return 1
  fi
}

# Función para renovar un certificado
renew_and_generate() {
  CLIENT="$1"
  RENEW_SUCCESS=0

  echo "=========================================="
  echo "  Procesando cliente: $CLIENT"
  echo "=========================================="

  # Verificar que el certificado existe
  if [ ! -f "$ISSUED_DIR/$CLIENT.crt" ]; then
    echo -e "${RED}ERROR:${NC} Certificado $CLIENT.crt no encontrado en $ISSUED_DIR"
    return 1
  fi

  # Verificar que la clave existe
  if [ ! -f "$PRIVATE_DIR/$CLIENT.key" ]; then
    echo -e "${YELLOW}ADVERTENCIA:${NC} Clave $CLIENT.key no encontrada en $PRIVATE_DIR"
    echo "  Se generara una nueva clave durante la renovacion"
  fi

  # Cambiar al directorio EasyRSA
  cd "$EASY_RSA_DIR" || {
    echo -e "${RED}ERROR:${NC} No se pudo acceder a $EASY_RSA_DIR"
    return 1
  }

  # Renovar el certificado del cliente
  echo "Renovando certificado para $CLIENT..."
  echo "yes" | ./easyrsa renew "$CLIENT" nopass

  if [ "$?" -eq 0 ]; then
    RENEW_SUCCESS=1
    echo -e "${GREEN}✓${NC} Certificado de $CLIENT renovado exitosamente"

    # Cambiar propietario y grupo de los archivos renovados
    echo "Aplicando permisos..."
    fix_permissions "$CLIENT"

  else
    echo -e "${RED}✗ ERROR:${NC} No se pudo renovar el certificado de $CLIENT"
    return 1
  fi

  # Solo continuar si la renovacion fue exitosa
  if [ "$RENEW_SUCCESS" -eq 1 ]; then
    # Generar archivo .ovpn con certificados embebidos
    generar_ovpn "$CLIENT"

    if [ "$?" -eq 0 ]; then
      echo ""
      echo -e "${GREEN}✅${NC} Configuracion para $CLIENT completada exitosamente"
      echo "  Archivo: $OUTPUT_DIR/$CLIENT.ovpn"
    else
      echo -e "${RED}ERROR:${NC} No se pudo generar el archivo .ovpn"
      return 1
    fi
  fi

  return 0
}

# Función para renovar todos los certificados
renovar_todos() {
  echo "=========================================="
  echo "  RENOVANDO TODOS LOS CERTIFICADOS"
  echo "=========================================="
  echo ""

  # Contar certificados
  CERT_COUNT=$(ls -1 "$ISSUED_DIR"/*.crt 2>/dev/null | wc -l)
  if [ "$CERT_COUNT" -eq 0 ]; then
    echo -e "${RED}ERROR:${NC} No se encontraron certificados en $ISSUED_DIR"
    return 1
  fi

  echo "Se encontraron $CERT_COUNT certificados para procesar"
  echo ""

  SUCCESS_COUNT=0
  FAIL_COUNT=0

  for CERT_FILE in "$ISSUED_DIR"/*.crt; do
    CLIENT=$(basename "$CERT_FILE" .crt)
    renew_and_generate "$CLIENT"

    if [ "$?" -eq 0 ]; then
      ((SUCCESS_COUNT++))
    else
      ((FAIL_COUNT++))
      echo -e "${YELLOW}⚠${NC} Continuando con el siguiente cliente..."
    fi
    echo ""
  done

  echo "=========================================="
  echo "  RESUMEN"
  echo "=========================================="
  echo "Total clientes procesados: $((SUCCESS_COUNT + FAIL_COUNT))"
  echo -e "${GREEN}Exitosos: $SUCCESS_COUNT${NC}"
  echo -e "${RED}Fallidos: $FAIL_COUNT${NC}"
}

# Función para mostrar información del cliente
mostrar_info_cliente() {
  local client="$1"

  echo "=========================================="
  echo "  INFORMACION DEL CLIENTE: $client"
  echo "=========================================="

  # Verificar certificado
  if [ -f "$ISSUED_DIR/$client.crt" ]; then
    echo -e "${GREEN}✓${NC} Certificado: $ISSUED_DIR/$client.crt"
    echo "  Fecha de expiracion:"
    openssl x509 -in "$ISSUED_DIR/$client.crt" -noout -enddate 2>/dev/null || echo "  No se pudo leer"
    echo "  Propietario: $(ls -l "$ISSUED_DIR/$client.crt" | awk '{print $3":"$4}')"
  else
    echo -e "${RED}✗${NC} Certificado no encontrado"
  fi

  echo ""

  # Verificar clave
  if [ -f "$PRIVATE_DIR/$client.key" ]; then
    echo -e "${GREEN}✓${NC} Clave: $PRIVATE_DIR/$client.key"
    echo "  Propietario: $(ls -l "$PRIVATE_DIR/$client.key" | awk '{print $3":"$4}')"
  else
    echo -e "${RED}✗${NC} Clave no encontrada"
  fi

  echo ""

  # Verificar archivo .ovpn
  if [ -f "$OUTPUT_DIR/$client.ovpn" ]; then
    echo -e "${GREEN}✓${NC} Archivo .ovpn: $OUTPUT_DIR/$client.ovpn"
    echo "  Tamaño: $(du -h "$OUTPUT_DIR/$client.ovpn" | cut -f1)"
    echo "  Fecha: $(stat -c %y "$OUTPUT_DIR/$client.ovpn" 2>/dev/null || stat -f %Sm "$OUTPUT_DIR/$client.ovpn" 2>/dev/null)"
  else
    echo -e "${YELLOW}⚠${NC} Archivo .ovpn no generado aun"
  fi
}

# Script principal
main() {
  echo "=========================================="
  echo "  RENOVACION DE CERTIFICADO VPN"
  echo "  OrangeBox Latam"
  echo "=========================================="
  echo ""

  # Verificar directorios
  if [ ! -d "$EASY_RSA_DIR" ]; then
    echo -e "${RED}ERROR:${NC} Directorio EasyRSA no encontrado: $EASY_RSA_DIR"
    exit 1
  fi

  if [ ! -d "$ISSUED_DIR" ]; then
    echo -e "${RED}ERROR:${NC} Directorio de certificados no encontrado: $ISSUED_DIR"
    exit 1
  fi

  # Verificar argumentos
  if [ $# -eq 0 ]; then
    mostrar_uso
  fi

  # Procesar argumentos
  case "$1" in
  -h | --help | help)
    mostrar_uso
    ;;
  all | --all | -a)
    renovar_todos
    ;;
  *)
    CLIENT="$1"

    # Verificar si el cliente existe
    if [ ! -f "$ISSUED_DIR/$CLIENT.crt" ]; then
      echo -e "${RED}ERROR:${NC} El cliente '$CLIENT' no existe"
      echo ""
      echo "Clientes disponibles:"
      ls -1 "$ISSUED_DIR"/*.crt 2>/dev/null | while read -r cert; do
        echo "  - $(basename "$cert" .crt)"
      done
      exit 1
    fi

    # Mostrar información antes de renovar
    mostrar_info_cliente "$CLIENT"
    echo ""

    # Confirmar renovación
    read -p "¿Deseas renovar el certificado de $CLIENT? (s/N): " CONFIRMAR
    if [[ ! "$CONFIRMAR" =~ ^[sS]$ ]]; then
      echo "Operación cancelada"
      exit 0
    fi

    echo ""

    # Renovar certificado
    renew_and_generate "$CLIENT"

    if [ "$?" -eq 0 ]; then
      echo ""
      echo -e "${GREEN}✅${NC} Renovación completada exitosamente"
      echo ""
      mostrar_info_cliente "$CLIENT"
    else
      echo ""
      echo -e "${RED}❌${NC} La renovación falló"
      exit 1
    fi
    ;;
  esac

  echo ""
  echo "=========================================="
  echo "  Permisos aplicados: root:zabbix-openvpn"
  echo "=========================================="
}

# Ejecutar script principal
main "$@"
