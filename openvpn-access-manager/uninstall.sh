#!/bin/bash
#
# OpenVPN Access Manager - Uninstall Script
# OrangeBox Latam
#
# Este script desinstala el sistema de control de acceso.
#
# Uso: sudo ./uninstall.sh
#

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Variables
OPENVPN_DIR="/etc/openvpn/server"
ACCESS_DIR="${OPENVPN_DIR}/access-manager"
CHAIN="OPENVPN"

echo "=========================================="
echo "  OpenVPN Access Manager - Desinstalación"
echo "=========================================="

# Verificar root
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}Error: Debe ejecutarse como root${NC}"
  exit 1
fi

echo -e "${YELLOW}[1/4] Eliminando cadena iptables...${NC}"
iptables -D FORWARD -j ${CHAIN} 2>/dev/null || true
iptables -F ${CHAIN} 2>/dev/null || true
iptables -X ${CHAIN} 2>/dev/null || true

echo -e "${YELLOW}[2/4] Eliminando archivos...${NC}"
rm -rf "${ACCESS_DIR}" 2>/dev/null || true

echo -e "${YELLOW}[3/4] Limpiando server.conf...${NC}"
if [ -f "${OPENVPN_DIR}/server.conf" ]; then
  sed -i '/learn-address/d' "${OPENVPN_DIR}/server.conf" 2>/dev/null || true
  sed -i '/client-config-dir/d' "${OPENVPN_DIR}/server.conf" 2>/dev/null || true
fi

echo -e "${YELLOW}[4/4] Guardando reglas...${NC}"
if command -v iptables-save &>/dev/null; then
  if [ -f /etc/redhat-release ]; then
    service iptables save 2>/dev/null || true
  else
    if command -v netfilter-persistent &>/dev/null; then
      netfilter-persistent save
    else
      iptables-save >/etc/iptables/rules.v4 2>/dev/null || true
    fi
  fi
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✅ Desinstalación completada${NC}"
echo "=========================================="
echo ""
echo "📝 Nota: Los archivos CCD se conservan en:"
echo "   ${OPENVPN_DIR}/ccd/"
echo ""
echo -e "${YELLOW}⚠  Si deseas eliminar los archivos CCD:${NC}"
echo "   rm -rf ${OPENVPN_DIR}/ccd/"
echo "=========================================="
