# Proyecto Final Integrador - Sistemas Operativos
## Administración de Servidor Linux para **Tienda El Tesoro** (Barrio Galán, Pereira)

---

### 1. Descripción del Caso y Necesidad
La organización elegida para este proyecto es **Tienda El Tesoro**, un establecimiento comercial de barrio ubicado en el barrio Galán de la ciudad de Pereira, Risaralda. Este negocio atiende diariamente a los vecinos del sector mediante la venta de víveres y abarrotes en dos jornadas de trabajo (mañana y tarde), además de gestionar compras y pagos periódicos con distintos proveedores. Actualmente, la tienda requiere centralizar y proteger su información operativa, ya que el registro manual de ventas y cuentas expone los datos a pérdidas accidentales o a modificaciones no autorizadas.

El servidor es utilizado por cuatro miembros de la tienda y un administrador técnico (`sebastian`). Sebastian (dueño) y Alba (administradora/contadora) necesitan acceso tanto a los registros de ventas como a la información financiera y facturas de proveedores. Por su parte, Miguel y Duvan se desempeñan como cajeros en los turnos de mañana y tarde respectivamente, por lo que únicamente requieren ingresar y consultar las ventas diarias sin acceder a los balances privados. La información crítica que no puede perderse corresponde a los registros diarios de ventas, los balances contables con facturas de proveedores y los reportes automáticos de estado generados por el servidor.

---

### 2. Diseño de Usuarios, Grupos y Permisos

#### 2.1 Tabla de Usuarios y Grupos

| Usuario | Persona / Rol | Grupo principal | Grupos adicionales | Justificación (Principio de mínimo privilegio) |
| :--- | :--- | :--- | :--- | :--- |
| `sebastian` | Dueño / Administrador TI | `sebastian` | `sudo`, `tienda`, `administracion` | Propietario de Tienda El Tesoro y administrador técnico del servidor. Tiene control total. |
| `alba` | Administradora / Contadora | `alba` | `tienda`, `administracion` | Encargada de facturas de proveedores y balances. Puede entrar a contabilidad y supervisar ventas. |
| `miguel` | Cajero turno mañana | `miguel` | `tienda` | Puede registrar y consultar ventas diarias en `ventas`, pero no entra a `contabilidad` ni tiene `sudo`. |
| `duvan` | Cajero turno tarde | `duvan` | `tienda` | Mismo nivel operativo que `miguel` para registrar ventas diarias, sin acceso a contabilidad ni `sudo`. |

#### 2.2 Estructura de Directorios y Permisos

| Carpeta | Dueño : Grupo | Permiso | Explicación (`rwx`) | Razón de la decisión |
| :--- | :--- | :--- | :--- | :--- |
| `/srv/tienda_tesoro` | `sebastian:tienda` | `750` | Dueño `rwx`, Grupo `r-x`, Otros `---` | Carpeta raíz del negocio: solo empleados y dueño pueden entrar (`x`) y listar (`r`); usuarios externos bloqueados (`---`). |
| `/srv/tienda_tesoro/ventas` | `sebastian:tienda` | `770` | Dueño `rwx`, Grupo `rwx`, Otros `---` | Todo el equipo (`tienda`) necesita leer y escribir (`w`) las ventas del día. |
| `/srv/tienda_tesoro/contabilidad` | `sebastian:administracion` | `770` | Dueño `rwx`, Grupo `rwx`, Otros `---` | Información financiera confidencial: solo `sebastian` y `alba` (grupo `administracion`) pueden entrar; los cajeros reciben `Permission denied`. |
| `/srv/tienda_tesoro/reportes` | `sebastian:tienda` | `755` | Dueño `rwx`, Grupo `r-x`, Otros `r-x` | El servicio automático escribe aquí los reportes; los empleados pueden consultarlos (`r-x`) pero no borrarlos ni editarlos. |

---

### 3. Servicio Propio en `systemd` (`tesoro-reporte.service`)
Para automatizar el seguimiento operativo de **Tienda El Tesoro**, se implementó el servicio `tesoro-reporte.service` en `/etc/systemd/system/tesoro-reporte.service`. Este servicio ejecuta en segundo plano el script `/usr/local/bin/tesoro_reporte.sh` (permisos `755`), registrando cada 60 segundos en `/srv/tienda_tesoro/reportes/actividad_tienda.log` la fecha y hora exacta, el conteo de ventas del día y el porcentaje de ocupación del disco.

La unidad se habilitó mediante `sudo systemctl enable --now tesoro-reporte` bajo `WantedBy=multi-user.target` para garantizar su inicio automático al encender el servidor, e incluye `Restart=always` con `RestartSec=3`, verificando su recuperación automática tras finalizar el proceso con `kill -9`.

---

### 4. Respaldo Automático con `tar` y `cron`
Se creó el directorio privado `/root/respaldos` con permisos `700` y el script `/usr/local/bin/respaldar_tienda.sh` (`755`), el cual comprime `/srv/tienda_tesoro` mediante `tar -czf` con marca de tiempo (`YYYYMMDD_HHMMSS`) y registra el estado (`OK` o `FALLO`) en `/root/respaldos/respaldo.log`. Se comprobó la integridad del respaldo restaurándolo en `/tmp/restauracion_prueba` y comparando con `diff -r`. Finalmente, se programó en `sudo crontab -e` para ejecutarse diariamente a las 2:00 a. m. (`0 2 * * * /usr/local/bin/respaldar_tienda.sh`).

---

### 5. Seguridad Básica Implementada
1. **Sin permisos `777`:** Se emplearon permisos mínimos (`750`, `770`, `755`, `700`), evitando lecturas o borrados no autorizados.
2. **Control estricto de `sudo`:** Únicamente `sebastian` posee privilegios administrativos; los cajeros (`miguel`, `duvan`) y `alba` operan sin `sudo`, mitigando errores humanos y escalada de privilegios.
3. **Actualización del sistema:** Gestión de parches mediante `apt update` y `apt upgrade` para reducir vulnerabilidades conocidas.
4. **Acceso nominal por SSH:** Conexión remota mediante el usuario `sebastian` en lugar de `root` directo, manteniendo trazabilidad en los registros del sistema.

---

### 6. Guía de Diagnóstico y Solución de Fallos
* **Falla en el servicio `tesoro-reporte`:** Verificar estado con `sudo systemctl status tesoro-reporte` y consultar errores con `sudo journalctl -u tesoro-reporte -n 30`. Tras editar el script o la unidad, ejecutar `sudo systemctl daemon-reload` y `sudo systemctl restart tesoro-reporte`.
* **Error `Permission denied` en carpetas de la tienda:** Validar grupos del usuario con `id usuario` y permisos del directorio con `ls -ld /srv/tienda_tesoro/ventas`. Corregir con `sudo usermod -aG tienda usuario` o `sudo chmod 770 /srv/tienda_tesoro/ventas`.
* **Falla en respaldos automáticos:** Revisar `/root/respaldos/respaldo.log` en busca de entradas `FALLO`, comprobar la programación en `sudo crontab -l`, el estado del demonio con `sudo systemctl status cron` y el espacio libre en disco con `df -h`.
