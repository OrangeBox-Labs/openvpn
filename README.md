# OpenVPN

Colección de herramientas, scripts y documentación para implementar, administrar y automatizar infraestructuras **OpenVPN** en entornos Linux.

Este repositorio reúne proyectos independientes desarrollados para resolver necesidades habituales en implementaciones empresariales, desde la instalación inicial hasta el control de acceso, automatización y administración de certificados.

Todos los proyectos están pensados para distribuciones **Red Hat Enterprise Linux**, **AlmaLinux** y **Rocky Linux**, priorizando soluciones simples, fáciles de mantener y orientadas a producción.

---

# Proyectos

## OpenVPN Access Manager

Control de acceso basado en grupos utilizando **learn-address** e **iptables**.

Permite definir permisos de acceso mediante archivos CCD y un archivo de configuración centralizado, sin necesidad de mantener reglas de firewall por usuario.

**Repositorio**

```
openvpn-access-manager/
```

Características principales:

- Control de acceso basado en grupos.
- Integración con OpenVPN.
- Administración centralizada.
- Compatible con Road Warrior y Site-to-Site.
- Política DROP por defecto.
- Fácil de extender.

---

## Próximamente

Este repositorio irá incorporando nuevos proyectos relacionados con OpenVPN.

Algunos de los desarrollos planificados son:

- Gestión automatizada de certificados.
- Scripts de respaldo y recuperación.
- Automatización de renovación de certificados.
- Auditoría y generación de reportes.
- Colección de utilidades para administración diaria.

---

# Requisitos generales

Dependiendo del proyecto, pueden ser necesarios algunos de los siguientes componentes.

- OpenVPN 2.6 o superior
- Red Hat Enterprise Linux 10
- AlmaLinux 10
- Rocky Linux 10
- Bash
- iptables
- Easy-RSA

Cada proyecto incluye su propia documentación e instrucciones de instalación.

---

# Objetivos

Los proyectos publicados en este repositorio siguen una filosofía común:

- Código simple y bien documentado.
- Configuración centralizada.
- Compatibilidad con distribuciones Enterprise Linux.
- Soluciones orientadas a entornos productivos.
- Scripts fáciles de modificar y mantener.
- Documentación técnica basada en experiencias reales.

---

# Documentación

Puedes encontrar documentación técnica y artículos relacionados con OpenVPN, Linux, monitoreo, automatización y seguridad en:

**Sitio web**

https://www.orangebox.cl

**Blog técnico**

https://www.orangebox.cl/blog/

---

# Contribuciones

Las contribuciones son bienvenidas.

Si encuentras un problema, tienes una sugerencia o deseas colaborar con el proyecto, puedes abrir un **Issue** o enviar un **Pull Request**.

---

# Autor

**OrangeBox Latam**

- Sitio web: https://www.orangebox.cl
- Blog: https://www.orangebox.cl/blog/
- Correo: info@orangebox.cl

---

# Licencia

Cada proyecto mantiene su propia licencia.

Salvo que se indique lo contrario, los proyectos publicados en este repositorio se distribuyen bajo la licencia **MIT**.
