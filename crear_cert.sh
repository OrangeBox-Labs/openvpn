#!/bin/bash

# autor: Felipe Román froman@orangebox.cl
# Descripción: script para crear los certificados de clientes o site-to-site de OpenVPN
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
  echo "  CREAR CERTIFICADO VPN"
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

remote vpn.orangebox.cl 1194

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

# Función para crear un nuevo certificado
crear_certificado() {
  CLIENT="$1"

  echo "=========================================="
  echo "  Creando certificado para: $CLIENT"
  echo "=========================================="

  # Verificar que el certificado no existe
  if [ -f "$ISSUED_DIR/$CLIENT.crt" ]; then
    echo -e "${YELLOW}ADVERTENCIA:${NC} El certificado $CLIENT.crt ya existe"
    read -p "¿Deseas sobrescribirlo? (s/N): " SOBRESCRIBIR
    if [[ ! "$SOBRESCRIBIR" =~ ^[sS]$ ]]; then
      echo "Operación cancelada"
      return 1
    fi
    echo ""
  fi

  # Cambiar al directorio EasyRSA
  cd "$EASY_RSA_DIR" || {
    echo -e "${RED}ERROR:${NC} No se pudo acceder a $EASY_RSA_DIR"
    return 1
  }

  # Generar el certificado del cliente
  echo "Generando certificado para $CLIENT..."
  echo "yes" | ./easyrsa gen-req "$CLIENT" nopass

  if [ "$?" -ne 0 ]; then
    echo -e "${RED}✗ ERROR:${NC} No se pudo generar la solicitud para $CLIENT"
    return 1
  fi

  echo "Firmando certificado para $CLIENT..."
  echo "yes" | ./easyrsa sign-req client "$CLIENT"

  if [ "$?" -ne 0 ]; then
    echo -e "${RED}✗ ERROR:${NC} No se pudo firmar el certificado para $CLIENT"
    return 1
  fi

  echo -e "${GREEN}✓${NC} Certificado de $CLIENT creado exitosamente"

  # Cambiar propietario y grupo de los archivos
  echo "Aplicando permisos..."
  fix_permissions "$CLIENT"

  # Generar archivo .ovpn con certificados embebidos
  generar_ovpn "$CLIENT"

  if [ "$?" -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅${NC} Certificado para $CLIENT creado exitosamente"
    echo "  Archivo: $OUTPUT_DIR/$CLIENT.ovpn"
    return 0
  else
    echo -e "${RED}ERROR:${NC} No se pudo generar el archivo .ovpn"
    return 1
  fi
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
  echo "  CREACION DE CERTIFICADO VPN"
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
  *)
    CLIENT="$1"

    # Verificar caracteres validos para el nombre
    if [[ ! "$CLIENT" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      echo -e "${RED}ERROR:${NC} El nombre del cliente solo puede contener letras, numeros, guiones y guiones bajos"
      exit 1
    fi

    # Verificar si el cliente ya existe
    if [ -f "$ISSUED_DIR/$CLIENT.crt" ]; then
      echo -e "${YELLOW}⚠${NC} El cliente '$CLIENT' ya existe"
      echo ""
      mostrar_info_cliente "$CLIENT"
      echo ""

      read -p "¿Deseas crear un nuevo certificado para $CLIENT? (s/N): " CONFIRMAR
      if [[ ! "$CONFIRMAR" =~ ^[sS]$ ]]; then
        echo "Operación cancelada"
        exit 0
      fi
      echo ""
    else
      echo "Creando nuevo cliente: $CLIENT"
      echo ""

      # Mostrar confirmación
      read -p "¿Confirmas la creación del certificado para $CLIENT? (s/N): " CONFIRMAR
      if [[ ! "$CONFIRMAR" =~ ^[sS]$ ]]; then
        echo "Operación cancelada"
        exit 0
      fi
      echo ""
    fi

    # Crear certificado
    crear_certificado "$CLIENT"

    if [ "$?" -eq 0 ]; then
      echo ""
      echo -e "${GREEN}✅${NC} Creación completada exitosamente"
      echo ""
      mostrar_info_cliente "$CLIENT"
    else
      echo ""
      echo -e "${RED}❌${NC} La creación falló"
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
