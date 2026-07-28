#!/bin/bash

# Autor: Felipe Román froman@orangebox.cl
# Descripción: script para renovar los certificados de clientes o site-to-site de OpenVPN
# y también corrige los permisos para que la plantilla de zabbix para chequear los certificados de OpenVPN pueda leerlos correctamente. (disponible en nuestro github https://github.com/OrangeBox-Labs/Zabbix )

# Directorios base
EASY_RSA_DIR="/etc/openvpn/server/easy-rsa/3"
PKI_DIR="$EASY_RSA_DIR/pki"
ISSUED_DIR="$PKI_DIR/issued"
PRIVATE_DIR="$PKI_DIR/private"
OUTPUT_DIR="/var/www/html/vpn"
CRL_FILE="$PKI_DIR/crl.pem"

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
  echo "  REVOCAR CERTIFICADO VPN"
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
  echo "Opciones:"
  echo "  -h, --help, help    Mostrar esta ayuda"
  echo "  -l, --list          Listar todos los clientes"
  echo "  -a, --all           Revocar TODOS los certificados (con confirmacion)"
  echo "=========================================="
  exit 1
}

# Función para listar clientes
listar_clientes() {
  echo "=========================================="
  echo "  CLIENTES VPN EXISTENTES"
  echo "=========================================="
  echo ""

  if [ ! -d "$ISSUED_DIR" ]; then
    echo -e "${RED}ERROR:${NC} Directorio de certificados no encontrado"
    return 1
  fi

  CERT_COUNT=$(ls -1 "$ISSUED_DIR"/*.crt 2>/dev/null | wc -l)
  if [ "$CERT_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No hay certificados de clientes${NC}"
    return 0
  fi

  echo "Se encontraron $CERT_COUNT clientes:"
  echo ""

  for CERT_FILE in "$ISSUED_DIR"/*.crt; do
    CLIENT=$(basename "$CERT_FILE" .crt)
    echo "  - $CLIENT"

    # Mostrar fecha de expiracion
    EXPIRACION=$(openssl x509 -in "$CERT_FILE" -noout -enddate 2>/dev/null | cut -d'=' -f2)
    if [ -n "$EXPIRACION" ]; then
      echo "    Expira: $EXPIRACION"
    fi

    # Verificar si ya esta revocado
    if [ -f "$CRL_FILE" ]; then
      if openssl crl -in "$CRL_FILE" -noout -text 2>/dev/null | grep -q "$CLIENT"; then
        echo -e "    Estado: ${RED}REVOCADO${NC}"
      else
        echo -e "    Estado: ${GREEN}ACTIVO${NC}"
      fi
    fi
    echo ""
  done
}

# Función para verificar si un certificado esta revocado
esta_revocado() {
  local client="$1"

  if [ ! -f "$CRL_FILE" ]; then
    return 1 # No revocado
  fi

  if openssl crl -in "$CRL_FILE" -noout -text 2>/dev/null | grep -q "$client"; then
    return 0 # Revocado
  else
    return 1 # No revocado
  fi
}

# Función para revocar un certificado
revocar_certificado() {
  local client="$1"

  echo "=========================================="
  echo "  Revocando certificado de: $CLIENT"
  echo "=========================================="

  # Verificar que el certificado existe
  if [ ! -f "$ISSUED_DIR/$client.crt" ]; then
    echo -e "${RED}ERROR:${NC} Certificado $client.crt no encontrado en $ISSUED_DIR"
    return 1
  fi

  # Verificar si ya esta revocado
  if esta_revocado "$client"; then
    echo -e "${YELLOW}⚠${NC} El certificado de $client ya fue revocado anteriormente"
    return 0
  fi

  # Cambiar al directorio EasyRSA
  cd "$EASY_RSA_DIR" || {
    echo -e "${RED}ERROR:${NC} No se pudo acceder a $EASY_RSA_DIR"
    return 1
  }

  # Revocar el certificado
  echo "Revocando certificado de $client..."
  echo "yes" | ./easyrsa revoke "$client"

  if [ "$?" -ne 0 ]; then
    echo -e "${RED}✗ ERROR:${NC} No se pudo revocar el certificado de $client"
    return 1
  fi

  echo -e "${GREEN}✓${NC} Certificado de $client revocado exitosamente"

  # Generar nueva CRL
  echo "Generando nueva lista de revocacion (CRL)..."
  echo "yes" | ./easyrsa gen-crl

  if [ "$?" -ne 0 ]; then
    echo -e "${YELLOW}ADVERTENCIA:${NC} No se pudo generar la CRL"
    echo "  Pero el certificado fue revocado"
    return 1
  fi

  echo -e "${GREEN}✓${NC} CRL generada exitosamente"

  # Copiar CRL al directorio de OpenVPN
  if [ -f "$CRL_FILE" ]; then
    cp "$CRL_FILE" "/etc/openvpn/server/crl.pem"
    chown root:zabbix-openvpn "/etc/openvpn/server/crl.pem"
    chmod 644 "/etc/openvpn/server/crl.pem"
    echo -e "${GREEN}✓${NC} CRL copiada a /etc/openvpn/server/crl.pem"
  fi

  # Cambiar permisos de la CRL
  if [ -f "$CRL_FILE" ]; then
    chown root:zabbix-openvpn "$CRL_FILE"
    chmod 644 "$CRL_FILE"
    echo -e "${GREEN}✓${NC} Permisos aplicados a CRL"
  fi

  # Eliminar archivo .ovpn si existe
  if [ -f "$OUTPUT_DIR/$client.ovpn" ]; then
    rm -f "$OUTPUT_DIR/$client.ovpn"
    echo -e "${GREEN}✓${NC} Archivo .ovpn eliminado de $OUTPUT_DIR"
  fi

  echo ""
  echo -e "${GREEN}✅${NC} Certificado de $client revocado exitosamente"
  echo "  CRL: $CRL_FILE"
  echo "  Copia: /etc/openvpn/server/crl.pem"

  return 0
}

# Función para mostrar informacion del cliente
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

    # Verificar si esta revocado
    if esta_revocado "$client"; then
      echo -e "  Estado: ${RED}REVOCADO${NC}"
    else
      echo -e "  Estado: ${GREEN}ACTIVO${NC}"
    fi
  else
    echo -e "${RED}✗${NC} Certificado no encontrado"
  fi

  echo ""

  # Verificar clave
  if [ -f "$PRIVATE_DIR/$client.key" ]; then
    echo -e "${GREEN}✓${NC} Clave: $PRIVATE_DIR/$client.key"
    echo "  Propietario: $(ls -l "$PRIVATE_DIR/$client.key" | awk '{print $3":"$4}')"
  else
    echo -e "${YELLOW}⚠${NC} Clave no encontrada"
  fi

  echo ""

  # Verificar archivo .ovpn
  if [ -f "$OUTPUT_DIR/$client.ovpn" ]; then
    echo -e "${GREEN}✓${NC} Archivo .ovpn: $OUTPUT_DIR/$client.ovpn"
    echo "  Tamaño: $(du -h "$OUTPUT_DIR/$client.ovpn" | cut -f1)"
    echo "  Fecha: $(stat -c %y "$OUTPUT_DIR/$client.ovpn" 2>/dev/null || stat -f %Sm "$OUTPUT_DIR/$client.ovpn" 2>/dev/null)"
  else
    echo -e "${YELLOW}⚠${NC} Archivo .ovpn no encontrado"
  fi
}

# Función para revocar todos los certificados
revocar_todos() {
  echo "=========================================="
  echo "  REVOCAR TODOS LOS CERTIFICADOS"
  echo "=========================================="
  echo ""

  # Contar certificados
  CERT_COUNT=$(ls -1 "$ISSUED_DIR"/*.crt 2>/dev/null | wc -l)
  if [ "$CERT_COUNT" -eq 0 ]; then
    echo -e "${RED}ERROR:${NC} No se encontraron certificados en $ISSUED_DIR"
    return 1
  fi

  echo -e "${RED}⚠ ADVERTENCIA:${NC} Esto revocara TODOS los certificados de clientes"
  echo "  Clientes afectados: $CERT_COUNT"
  echo ""

  # Listar clientes
  echo "Clientes que seran revocados:"
  for CERT_FILE in "$ISSUED_DIR"/*.crt; do
    CLIENT=$(basename "$CERT_FILE" .crt)
    echo "  - $CLIENT"
  done
  echo ""

  # Confirmacion multiple
  read -p "¿Estas SEGURO de revocar TODOS los certificados? (escribe 'REVOCAR' para confirmar): " CONFIRMAR
  if [ "$CONFIRMAR" != "REVOCAR" ]; then
    echo "Operación cancelada"
    return 0
  fi

  echo ""

  SUCCESS_COUNT=0
  FAIL_COUNT=0

  for CERT_FILE in "$ISSUED_DIR"/*.crt; do
    CLIENT=$(basename "$CERT_FILE" .crt)
    revocar_certificado "$CLIENT"

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

# Script principal
main() {
  echo "=========================================="
  echo "  REVOCACION DE CERTIFICADO VPN"
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
  -l | --list)
    listar_clientes
    ;;
  -a | --all)
    revocar_todos
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

    # Mostrar información del cliente
    mostrar_info_cliente "$CLIENT"
    echo ""

    # Verificar si ya esta revocado
    if esta_revocado "$CLIENT"; then
      echo -e "${YELLOW}⚠${NC} Este certificado ya fue revocado"
      exit 0
    fi

    # Confirmar revocación
    echo -e "${RED}⚠ ATENCION:${NC} Esta accion es IRREVERSIBLE"
    echo "  El cliente $CLIENT perdera acceso a la VPN"
    echo ""
    read -p "¿Confirmas la revocacion del certificado de $CLIENT? (escribe 'REVOCAR' para confirmar): " CONFIRMAR

    if [ "$CONFIRMAR" != "REVOCAR" ]; then
      echo "Operación cancelada"
      exit 0
    fi

    echo ""

    # Revocar certificado
    revocar_certificado "$CLIENT"

    if [ "$?" -eq 0 ]; then
      echo ""
      echo -e "${GREEN}✅${NC} Revocacion completada exitosamente"
      echo ""
      echo "Para que los cambios surtan efecto, reinicia OpenVPN:"
      echo "  systemctl restart openvpn-server@server"
    else
      echo ""
      echo -e "${RED}❌${NC} La revocacion fallo"
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
