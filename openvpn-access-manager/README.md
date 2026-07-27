# OpenVPN Access Manager

Control de acceso basado en grupos para OpenVPN utilizando **learn-address** e **iptables**.

OpenVPN Access Manager permite controlar el acceso a redes y servicios internos sin modificar la configuración de OpenVPN ni mantener reglas de firewall por usuario.

Cada cliente VPN obtiene sus permisos desde su archivo **CCD**, mientras que los grupos y recursos disponibles se administran desde un único archivo de configuración (`access.conf`).

El objetivo es separar claramente la autenticación de la autorización:

- **OpenVPN** autentica al cliente.
- **OpenVPN Access Manager** determina a qué recursos puede acceder.
- **iptables** aplica las políticas de acceso.

---

# Características

- Administración de permisos basada en grupos.
- Integración con `learn-address`.
- Compatible con OpenVPN Road Warrior y Site-to-Site.
- Configuración centralizada mediante `access.conf`.
- Gestión de usuarios mediante archivos CCD.
- Permisos por dirección IP o redes completas (CIDR).
- Política **DROP** por defecto.
- Compatible con Red Hat Enterprise Linux, AlmaLinux y Rocky Linux.
- Fácil de extender agregando nuevos grupos de acceso.
- Sin modificaciones al código al incorporar nuevos usuarios.

---

# Arquitectura

```
               OpenVPN
                   │
                   ▼
          Autenticación
                   │
                   ▼
              Archivo CCD
          (# ACCESS=...)
                   │
                   ▼
          learn-address.sh
                   │
                   ▼
             access.conf
                   │
                   ▼
              iptables
                   │
                   ▼
      Recursos permitidos
```

---

# Estructura

```
/etc/openvpn/server/

├── server.conf
├── ccd/
│   ├── cliente1
│   ├── cliente2
│   └── ...
│
└── access-manager/
    ├── access.conf
    ├── learn-address.sh
    ├── install.sh
    └── uninstall.sh
```

---

# Instalación

```bash
git clone https://github.com/OrangeBox-Labs/openvpn-access-manager.git

cd openvpn-access-manager

./install.sh
```

---

# Configuración

Toda la configuración se realiza desde `access.conf`.

Ejemplo:

```bash
GROUP_DNS="192.168.10.2"

GROUP_WEB="192.168.10.20,192.168.10.21"

GROUP_FILESERVER="192.168.10.30"

GROUP_AD="192.168.10.10,192.168.10.11"

GROUP_MONITOREO="192.168.200.240"

GROUP_BACKUP="192.168.50.20"

GROUP_VCENTER="192.168.100.50"

GROUP_DMZ="172.16.0.0/24"

GROUP_LAN="192.168.0.0/16"

GROUP_INTERNET="0.0.0.0/0"

GROUP_VIP="ALL"
```

Agregar un nuevo grupo sólo requiere definir una nueva variable.

---

# Asignar permisos

Cada cliente obtiene sus permisos desde su archivo CCD.

Ejemplo:

```conf
ifconfig-push 10.100.0.10 255.255.255.0

# ACCESS=DNS,WEB,FILESERVER
```

Administrador:

```conf
ifconfig-push 10.100.0.20 255.255.255.0

# ACCESS=VIP
```

Proveedor:

```conf
ifconfig-push 10.100.0.30 255.255.255.0

# ACCESS=WEB
```

---

# Casos de uso

| Perfil | Permisos |
|---------|----------|
| Administrador | `VIP` |
| Operador NOC | `DNS,MONITOREO` |
| Equipo Web | `WEB,DMZ` |
| VMware | `VCENTER` |
| Backups | `BACKUP` |
| Proveedor | `WEB` |

---

# Comandos útiles

Mostrar reglas activas.

```bash
iptables -L OPENVPN -v -n
```

Vaciar reglas.

```bash
iptables -F OPENVPN
```

Reiniciar OpenVPN.

```bash
systemctl restart openvpn-server@server
```

---

# Compatibilidad

- OpenVPN 2.6 o superior
- Red Hat Enterprise Linux 10
- AlmaLinux 10
- Rocky Linux 10
- iptables

---

# Roadmap

- [ ] Compatibilidad con nftables.
- [ ] Soporte para IPv6.
- [ ] Sistema de logging configurable.
- [ ] Validación automática de la configuración.
- [ ] Pruebas automatizadas.
- [ ] Paquetes RPM.

---

# Autor

**OrangeBox Latam**

🌐 https://www.orangebox.cl

📧 info@orangebox.cl

Documentación técnica y artículos relacionados:

https://www.orangebox.cl/blog/

---

# Licencia

MIT License.
