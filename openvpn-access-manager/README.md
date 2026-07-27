# OpenVPN Access Manager

## Descripcion

Sistema de control de acceso basado en roles (RBAC) para OpenVPN. Permite gestionar permisos de red mediante un archivo de configuracion centralizado, sin necesidad de modificar scripts.

## Caracteristicas

- Control de acceso basado en roles (RBAC)
- Configuracion centralizada en access.conf
- Gestion simple de usuarios mediante archivos CCD
- Soporte para multiples servicios (DNS, WEB, FILESERVER, etc.)
- Permisos granulares por red o direccion IP
- Escalable - agregar nuevos servicios solo requiere una linea
- Totalmente transparente para OpenVPN

## Arquitectura

OpenVPN (autenticacion + asignacion IP)
   ↓
CCD (define IP fija + roles)
   ↓
learn-address.sh (lee CCD + aplica reglas)
   ↓
access.conf (define servicios y redes)
   ↓
iptables (control de acceso)

## Estructura de Archivos

/etc/openvpn/server/
├── server.conf
├── ccd/
│   ├── cliente1
│   ├── cliente2
│   └── ...
└── access-manager/
    ├── learn-address.sh
    ├── access.conf
    ├── install.sh
    └── uninstall.sh

## Instalacion Rapida

# Clonar el repositorio
git clone https://github.com/orangebox/openvpn-access-manager.git

# Ir al directorio
cd openvpn-access-manager

# Ejecutar instalacion
sudo ./install.sh

## Configuracion

### 1. Definir Servicios en access.conf

# Servicios de red
GROUP_DNS="192.168.10.2"
GROUP_WEB="192.168.10.20,192.168.10.21"
GROUP_FILESERVER="192.168.10.30"
GROUP_MONITOREO="192.168.200.240"
GROUP_AD="192.168.10.10,192.168.10.11"

# Redes
GROUP_DMZ="172.16.0.0/24"
GROUP_LAN="192.168.0.0/16"

# Acceso total
GROUP_VIP="ALL"

# Internet (requiere NAT)
GROUP_INTERNET="0.0.0.0/0"

### 2. Asignar Roles en CCD

# /etc/openvpn/server/ccd/felipe
ifconfig-push 10.100.0.10 255.255.255.0
# ACCESS=DNS,WEB,FILESERVER

# /etc/openvpn/server/ccd/administrador
ifconfig-push 10.100.0.30 255.255.255.0
# ACCESS=VIP

# /etc/openvpn/server/ccd/proveedor
ifconfig-push 10.100.0.40 255.255.255.0
# ACCESS=WEB

## Comandos Utiles

# Ver reglas actuales
sudo iptables -L OPENVPN -v -n

# Ver conexiones activas
sudo iptables -L OPENVPN -v -n | grep 10.100

# Limpiar todas las reglas
sudo iptables -F OPENVPN

# Reiniciar el servicio
sudo systemctl restart openvpn-server@server

## Ejemplos de Casos de Uso

### Administrador de Sistemas

# ACCESS=DNS,WEB,FILESERVER,AD,VCENTER,BACKUP

Acceso a todos los servicios de infraestructura.

### Desarrollador Web

# ACCESS=WEB,DMZ

Acceso a servidores web y zona DMZ.

### Auditor de Seguridad

# ACCESS=MONITOREO,BACKUP,AD

Acceso a sistemas de monitoreo, backups y Active Directory.

### Proveedor Externo

# ACCESS=WEB

Acceso limitado solo a servidores web.

## Seguridad

- Politica DROP por defecto
- Acceso granular por IP/red
- Separacion de responsabilidades
- Logs detallados de conexiones

## Contribuciones

Las contribuciones son bienvenidas. Por favor, lee nuestras guias de contribucion antes de enviar un PR.

## Licencia

MIT License - Copyright (c) 2024 OrangeBox Latam

## Equipo

Desarrollado y mantenido por el equipo de OrangeBox Chile
