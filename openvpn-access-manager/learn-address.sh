#!/bin/bash
#
# OpenVPN Access Manager - learn-address.sh
# OrangeBox Latam
#
# Script de control de acceso basado en roles (RBAC) para OpenVPN.
#
# Este script es llamado por OpenVPN cuando un cliente se conecta o desconecta.
# Lee el archivo CCD del cliente, obtiene los grupos de acceso y aplica
# las reglas iptables correspondientes.
#
# Parámetros recibidos de OpenVPN:
#   $1: Dirección IP del cliente (ej: 10.100.0.10)
#   $2: Nombre común del certificado (ej: felipe)
#   $3: Estado de la conexión (add | delete | update)
#
# Uso: learn-address.sh <ip> <common_name> <action>
#

set -e

# Colores para logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Variables
OPENVPN_DIR="/etc/openvpn/server"
ACCESS_DIR="${OPENVPN_DIR}/access-manager"
CCD_DIR="${OPENVPN_DIR}/ccd"
CONFIG_FILE="${ACCESS_DIR}/access.conf"
LOG_FILE="/var/log/openvpn-access.log"

# Función: log
log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo "$msg" >>"$LOG_FILE"
  echo -e "$msg"
}

# Función: obtener_grupo
obtener_grupo() {
  local grupo="$1"
  eval echo "\$GROUP_${grupo}"
}

# Función: verificar_cadena
verificar_cadena() {
  local chain="$1"
  if ! iptables -L "$chain" -n &>/dev/null; then
    log "${YELLOW}Creando cadena ${chain}...${NC}"
    iptables -N "$chain" 2>/dev/null || true
    iptables -C FORWARD -j "$chain" 2>/dev/null ||
      iptables -I FORWARD -j "$chain"
  fi
}

# Función: cargar_configuracion
cargar_configuracion() {
  if [ ! -f "$CONFIG_FILE" ]; then
    log "${RED}Error: Archivo de configuración no encontrado: $CONFIG_FILE${NC}"
    return 1
  fi

  # Cargar configuración
  source "$CONFIG_FILE"

  # Obtener cadena y política por defecto
  CHAIN="${CHAIN:-OPENVPN}"
  DEFAULT_POLICY="${DEFAULT_POLICY:-DROP}"

  log "${GREEN}Configuración cargada:${NC}"
  log "  Cadena: ${CHAIN}"
  log "  Política: ${DEFAULT_POLICY}"

  # Verificar cadena
  verificar_cadena "$CHAIN"

  return 0
}

# Función: aplicar_reglas
aplicar_reglas() {
  local ip="$1"
  local common_name="$2"
  local action="$3"

  log "=========================================="
  log "Procesando cliente: ${common_name} (${ip})"
  log "Acción: ${action}"
  log "=========================================="

  # Cargar configuración
  if ! cargar_configuracion; then
    return 1
  fi

  # Buscar archivo CCD
  local ccd_file="${CCD_DIR}/${common_name}"
  if [ ! -f "$ccd_file" ]; then
    log "${YELLOW}Archivo CCD no encontrado: ${ccd_file}${NC}"
    return 1
  fi

  # Extraer grupos de acceso
  local access_line=$(grep "^# ACCESS=" "$ccd_file" | head -n1)
  if [ -z "$access_line" ]; then
    log "${YELLOW}No se encontró # ACCESS= en ${ccd_file}${NC}"
    log "${YELLOW}El cliente ${common_name} tendrá acceso denegado${NC}"
    return 1
  fi

  # Obtener lista de grupos
  local grupos=$(echo "$access_line" | cut -d'=' -f2 | tr -d ' ')
  log "${GREEN}Grupos asignados: ${grupos}${NC}"

  # Separar grupos por coma
  IFS=',' read -ra GRUPOS_ARRAY <<<"$grupos"

  # Construir reglas de IPTABLES
  log "Aplicando reglas para ${ip}..."

  # Si hay grupos VIP, permitir acceso total
  local vip_enabled=0
  for grupo in "${GRUPOS_ARRAY[@]}"; do
    if [ "$grupo" = "VIP" ]; then
      vip_enabled=1
      log "${GREEN}Acceso VIP detectado${NC}"
      break
    fi
  done

  if [ "$vip_enabled" -eq 1 ]; then
    iptables -A "$CHAIN" -s "$ip" -j ACCEPT
    log "${GREEN}✓ Regla VIP agregada${NC}"
  else
    # Procesar cada grupo
    local reglas_agregadas=0
    for grupo in "${GRUPOS_ARRAY[@]}"; do
      # Buscar el grupo en la configuración
      local destinos=$(obtener_grupo "$grupo")

      if [ -z "$destinos" ]; then
        log "${YELLOW}Grupo '${grupo}' no definido en access.conf${NC}"
        continue
      fi

      # Si el grupo tiene "ALL", permitir acceso total
      if [ "$destinos" = "ALL" ]; then
        iptables -A "$CHAIN" -s "$ip" -j ACCEPT
        log "${GREEN}✓ Acceso TOTAL permitido${NC}"
        reglas_agregadas=1
        break
      fi

      # Dividir destinos por coma
      IFS=',' read -ra DESTINOS_ARRAY <<<"$destinos"

      # Agregar reglas para cada destino
      for destino in "${DESTINOS_ARRAY[@]}"; do
        if iptables -A "$CHAIN" -s "$ip" -d "$destino" -j ACCEPT; then
          log "${GREEN}✓ ACCEPT: ${ip} -> ${destino}${NC}"
          ((reglas_agregadas++))
        else
          log "${RED}✗ ERROR: ${ip} -> ${destino}${NC}"
        fi
      done
    done

    if [ "$reglas_agregadas" -eq 0 ]; then
      log "${YELLOW}No se agregaron reglas de acceso${NC}"
    else
      log "${GREEN}✓ Se agregaron ${reglas_agregadas} reglas${NC}"
    fi
  fi

  # Agregar regla DROP por defecto
  iptables -A "$CHAIN" -s "$ip" -j DROP
  log "${YELLOW}✓ DROP por defecto agregado${NC}"

  return 0
}

# Función: eliminar_reglas
eliminar_reglas() {
  local ip="$1"
  local common_name="$2"

  log "Eliminando reglas para ${common_name} (${ip})..."

  # Eliminar todas las reglas que coincidan con la IP
  while iptables -D "$CHAIN" -s "$ip" -j ACCEPT 2>/dev/null; do
    :
  done

  while iptables -D "$CHAIN" -s "$ip" -j DROP 2>/dev/null; do
    :
  done

  # Eliminar reglas específicas con destino
  while iptables -D "$CHAIN" -s "$ip" -d 0.0.0.0/0 -j ACCEPT 2>/dev/null; do
    :
  done

  log "${GREEN}✓ Reglas eliminadas${NC}"
}

# Función: main
main() {
  # Verificar argumentos
  if [ $# -lt 3 ]; then
    log "${RED}Error: Se requieren 3 argumentos${NC}"
    log "Uso: $0 <ip> <common_name> <action>"
    exit 1
  fi

  local ip="$1"
  local common_name="$2"
  local action="$3"

  # Obtener cadena
  CHAIN="OPENVPN"

  case "$action" in
  add | update)
    # Primero eliminar reglas antiguas (si existen)
    eliminar_reglas "$ip" "$common_name"
    # Aplicar nuevas reglas
    aplicar_reglas "$ip" "$common_name" "$action"
    ;;
  delete)
    eliminar_reglas "$ip" "$common_name"
    ;;
  *)
    log "${RED}Error: Acción desconocida: ${action}${NC}"
    exit 1
    ;;
  esac

  # Mostrar estado actual
  log "Estado actual de la cadena ${CHAIN}:"
  iptables -L "$CHAIN" -v -n | grep -E "(Chain|${ip})" | while read -r line; do
    log "  $line"
  done
  log "=========================================="
}

# Ejecutar función principal
main "$@"
