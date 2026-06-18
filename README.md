# Emulación de Adversarios en Entornos Cloud mediante MITRE Caldera

## Resumen del Proyecto

El presente Trabajo de Fin de Grado diseña y despliega un entorno de laboratorio en Microsoft Azure bajo la metodología **Purple Team** para validar la eficacia de la **Arquitectura Zero Trust (ZTA)**. 

Mediante el uso de Infraestructura como Código (**Terraform**) y el framework de emulación **MITRE Caldera**, se modelan y ejecutan cinco vectores de ataque críticos contemporáneos:
* **UNC5537** (Exfiltración masiva SaaS)
* **STORM-0558** (Falsificación criptográfica profunda y espionaje)
* **CVE-2025-55241** (Suplantación de Servicio a Servicio y Actor Tokens)
* **CVE-2026-2473** (Bucket Squatting y secuestro de flujo en IA)
* **React2Shell / CVE-2025-55182** (Fileless Backdoor y contaminación de prototipos)

El laboratorio contrasta un entorno base "*Vulnerable by Design*" frente a una infraestructura fortificada a lo largo de **tres fases de hardening incremental** (Contención Táctica, Defensa Perimetral y Zero Trust Estructural). Los resultados empíricos logran una reducción de la Tasa de Éxito de Ataques (ASR) del 100% al 0%, certificando la efectividad del despliegue defensivo.

---

## Manual de Instalación y Guía de Operaciones

Para garantizar la transparencia, reproducibilidad y auditoría del entorno Cloud y las tácticas ofensivas descritas en esta memoria, todo el código fuente, los manifiestos de infraestructura como código (Terraform) y los scripts de aprovisionamiento han sido depositados en este repositorio público en la plataforma GitHub.

El material técnico puede consultarse directamente a través de la siguiente URL: `https://github.com/alonsocanadilla1/UAH-EmulacionDeAdversariosEnEntornosCloudMedianteMitreCaldera.git`

### Fase 1: Preparación del Entorno y Código

1. **Descarga del Repositorio:** Clonar el código fuente que contiene los manifiestos de Terraform y los scripts de aprovisionamiento en la máquina local del operador:
   ```bash
   git clone https://github.com/alonsocanadilla1/UAH-EmulacionDeAdversariosEnEntornosCloudMedianteMitreCaldera.git
   ```
2. **Configuración de Claves SSH:** Abrir el archivo `caldera-install.sh`. Localizar el bloque de la clave SSH y sustituir la clave privada/pública por la clave del dispositivo local del operador. *(Para obtener una nueva clave en Linux, ejecutar `ssh-keygen -t rsa -b 4096`; para visualizarla, ejecutar `cat ~/.ssh/id_rsa.pub`).*
3. **Inyección del Dominio (Tenant):** En los documentos `.tf` y scripts requeridos, buscar la etiqueta `<DOMINIO>` y reemplazarla por el dominio principal de la cuenta de Entra ID que se utilizará. *(Este dominio se puede obtener accediendo al Portal de Azure -> Entra ID -> Información General -> Dominio Principal, ej: midominio.onmicrosoft.com).*

### Fase 2: Despliegue de la Infraestructura (Terraform)

4. **Autenticación en Azure:** Abrir una terminal y ejecutar `az login`. Seleccionar la cuenta administrativa adecuada y fijar la suscripción de trabajo.
5. **Aprovisionamiento:** Navegar a la carpeta correspondiente a la fase que se desea auditar. Ejecutar:
   * `terraform init` (Para descargar los proveedores y módulos).
   * `terraform apply -auto-approve` (Para materializar la arquitectura en la nube).
6. **Espera de Compilación (CRÍTICO):** Una vez que Terraform indique "Apply complete" y devuelva por pantalla la IP del servidor Caldera, es **obligatorio esperar 10 minutos de reloj**. Durante este tiempo invisible, el proceso `cloud-init` de la máquina virtual está instalando dependencias, clonando repositorios y compilando los agentes ofensivos en lenguaje Go.

### Fase 3: Orquestación del Comando y Control (MITRE Caldera)

7. **Acceso SSH Inicial:** Transcurridos los 10 minutos, conectar al servidor C2 usando la IP devuelta por Terraform:
   ```bash
   ssh azureuser@<IP_DE_CALDERA>
   ```
8. **Escalada e Identidad Ofensiva:** Una vez dentro de la máquina, escalar hacia el usuario que ejecuta el servicio ofensivo: `sudo su - caldera`. Acto seguido, forzar a la máquina del atacante a adquirir un contexto en la nube (Paso vital para ejecutar vectores como el CVE-2026-2473):
   ```bash
   az login --use-device-code
   ```
   *(Seguir las instrucciones en pantalla para autenticar el dispositivo).*
9. **Acceso a la Interfaz Gráfica:** En el navegador web de la máquina local, acceder a `http://<IP_DE_CALDERA>:8888`. Iniciar sesión en el portal de MITRE Caldera con las credenciales por defecto: **Usuario:** `admin`, **Contraseña:** `admin`.
10. **Despliegue del Implante (Sandcat):** En la interfaz de Caldera, navegar a *Agents* -> Click en *"Deploy an agent"* -> Seleccionar *Sandcat* -> Elegir sistema operativo *Linux*. Copiar el comando `curl` generado automáticamente por la interfaz. Retornar a la terminal SSH (contexto en el cual se ha asumido la identidad del usuario caldera) y ejecutar. El agente aparecerá como "Vivo" (Verde) en el Dashboard.
11. **Ejecución del Ciberataque:** Navegar a la pestaña *Operations*, crear una nueva operación y seleccionar el *Adversario* (vector de ataque) que se desee validar. Observar en tiempo real la ejecución de la Kill Chain y analizar los logs y flags devueltas por la salida estándar.

### Fase 4: Clausura e Iteración

12. **Destrucción del Entorno:** Una vez finalizada la extracción de telemetría de una fase, salir del servidor SSH y, en la terminal local, destruir de forma atómica la infraestructura para detener la facturación y evitar compromisos reales:
    ```bash
    terraform destroy -auto-approve
    ```
13. **Iteración de Fases:** Para evaluar el impacto de los siguientes controles de seguridad (Fases de Hardening), acceder a la carpeta de la siguiente fase y repetir de forma íntegra el proceso desde el Paso 5.
