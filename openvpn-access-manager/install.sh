#!/bin/bash
#
# OpenVPN Access Manager - Install Script
# OrangeBox Latam
#
# Este script instala el sistema de control de acceso para OpenVPN.
# Crea la cadena iptables y configura el script learn-address.
#
# Uso: sudo ./install.sh
#

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables
OPENVPN_DIR="/etc/openvpn/server"
ACCESS_DIR="${OPENVPN_DIR}/access-manager"
CHAIN="OPENVPN"

echo "=========================================="
echo "  OpenVPN Access Manager - Instalación"
echo "  OrangeBox Latam"
echo "=========================================="

# Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}Error: Este script debe ejecutarse como root${NC}"
  exit 1
fi

# Verificar OpenVPN
if ! command -v openvpn &>/dev/null; then
  echo -e "${RED}Error: OpenVPN no está instalado${NC}"
  exit 1
fi

# Verificar iptables
if ! command -v iptables &>/dev/null; then
  echo -e "${RED}Error: iptables no está instalado${NC}"
  exit 1
fi

# Crear directorios
echo -e "${YELLOW}[1/5] Creando directorios...${NC}"
mkdir -p "${ACCESS_DIR}"
mkdir -p "${OPENVPN_DIR}/ccd"

# Copiar archivos
echo -e "${YELLOW}[2/5] Copiando archivos...${NC}"
cp access.conf "${ACCESS_DIR}/"
cp learn-address.sh "${ACCESS_DIR}/"
chmod +x "${ACCESS_DIR}/learn-address.sh"

# Verificar configuración de OpenVPN
echo -e "${YELLOW}[3/5] Configurando OpenVPN...${NC}"
if ! grep -q "learn-address" "${OPENVPN_DIR}/server.conf" 2>/dev/null; then
  echo "script-security 2" >>"${OPENVPN_DIR}/server.conf"
  echo "learn-address ${ACCESS_DIR}/learn-address.sh" >>"${OPENVPN_DIR}/server.conf"
  echo "client-config-dir ${OPENVPN_DIR}/ccd" >>"${OPENVPN_DIR}/server.conf"
  echo -e "${GREEN}✓ OpenVPN configurado${NC}"
else
  echo -e "${YELLOW}⚠ OpenVPN ya está configurado${NC}"
fi

# Crear cadena iptables
echo -e "${YELLOW}[4/5] Creando cadena iptables...${NC}"
iptables -N ${CHAIN} 2>/dev/null || true
iptables -C FORWARD -j ${CHAIN} 2>/dev/null ||
  iptables -I FORWARD -j ${CHAIN}

# Verificar
echo -e "${YELLOW}[5/5] Verificando instalación...${NC}"
if iptables -L ${CHAIN} -n &>/dev/null; then
  echo -e "${GREEN}✓ Cadena ${CHAIN} creada correctamente${NC}"
else
  echo -e "${RED}✗ Error al crear la cadena ${CHAIN}${NC}"
  exit 1
fi

# Guardar reglas (persistente)
if command -v iptables-save &>/dev/null; then
  if [ -f /etc/redhat-release ]; then
    # RedHat/CentOS
    service iptables save 2>/dev/null || true
  else
    # Debian/Ubuntu
    if command -v netfilter-persistent &>/dev/null; then
      netfilter-persistent save
    else
      iptables-save >/etc/iptables/rules.v4 2>/dev/null || true
    fi
  fi
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✅ Instalación completada${NC}"
echo "=========================================="
echo ""
echo "📁 Archivos instalados:"
echo "   ${ACCESS_DIR}/access.conf"
echo "   ${ACCESS_DIR}/learn-address.sh"
echo ""
echo "📝 Configuración:"
echo "   1. Editar ${ACCESS_DIR}/access.conf"
echo "   2. Crear archivos en ${OPENVPN_DIR}/ccd/"
echo "   3. Reiniciar OpenVPN: systemctl restart openvpn-server@server"
echo ""
echo "📖 Ejemplo de archivo CCD:"
echo "   ${OPENVPN_DIR}/ccd/usuario"
echo "   ifconfig-push 10.100.0.10 255.255.255.0"
echo "   # ACCESS=DNS,WEB,FILESERVER"
echo ""
echo -e "${YELLOW}⚠  Importante: Verificar que el script security esté habilitado${NC}"
echo "   En server.conf debe tener: script-security 2"
echo "=========================================="
