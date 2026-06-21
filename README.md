# Qúbico Transportes - Demo Funcional (MVP)

![Qúbico Transportes](https://img.shields.io/badge/Flutter-App-blue?logo=flutter) ![SQLite](https://img.shields.io/badge/Database-SQLite-blue?logo=sqlite) ![Status](https://img.shields.io/badge/Estado-Demo_Usable-brightgreen)

Qúbico Transportes es una aplicación móvil corporativa (B2B) desarrollada en **Flutter** para la gestión integral de logística, despacho y transporte de carga. Esta demo representa un **Minimum Viable Product (MVP)** robusto, enfocado en conectar la administración central con los conductores en ruta a través de flujos de trabajo inteligentes en tiempo real.

---

## Perfiles de Usuario y Credenciales de Acceso

La aplicación cuenta con validación de credenciales en local y segmentación de permisos según el rol.

* **Administrador:** `admin@qubico.cl` / Contraseña: `admin123`
* **Conductor:** `conductor@qubico.cl` / Contraseña: `conductor123`

*(Nota: La pantalla de Login incluye opción para visualizar la contraseña y protección frente a múltiples intentos fallidos).*

---

## Características y Funcionalidades Principales

### 1. Panel de Administración (Vista Admin)
Diseñado para el control absoluto de las operaciones logísticas y la flota.

* **Dashboard (Inicio):** Indicadores clave de rendimiento (KPIs) diarios. Pedidos completados, incidencias y distribución de estados en gráficas y tarjetas de resumen.
* **Monitor en Tiempo Real:** 
    * Seguimiento de pedidos del día con estados en vivo (`Pendiente`, `En camino`, `Entregado`, `Incidencia`).
    * **Mapa interactivo** integrado con geolocalización de pedidos en curso.
    * **Bitácora de Eventos:** Auditoría automática del pedido (`AdminOrderDetailScreen`). Permite ver hora, actor y detalle de cualquier cambio de estado.
* **Creación de Despachos (Nuevo):**
    * Formulario dinámico para nuevos pedidos.
    * Autocompletado inteligente de **Clientes Frecuentes** o ingreso manual (con desglose de Dirección en *Calle, Número y Comuna*).
    * Cálculo de dimensiones y volumetría de la carga.
    * Asignación inmediata al vehículo y conductor idóneo según la disponibilidad.
* **Historial de Despachos:** Consulta de todos los pedidos históricos. Incorpora filtros por estado y fechas, con capacidad de **Exportación y generación de guías de despacho en PDF**.
* **Ajustes y Mantenimiento:**
    * **Gestión de Flota:** Mantenedor de vehículos (patente, capacidad máxima de carga, dimensiones).
    * **Gestión de Usuarios:** Mantenedor de cuentas de conductores y personal administrativo.
    * **Reportes Avanzados:** Gráficos y consolidación mensual.

### 2. Experiencia del Conductor (Hoja de Ruta)
Interfaz enfocada en usabilidad, diseñada para no distraer y facilitar entregas eficientes.

* **Hoja de Ruta Dinámica:**
    * Línea de tiempo visual con las paradas programadas del día.
    * Botón dinámico de acción: **"Iniciar Entrega"** → **"Terminar Entrega"**.
    * Al *Iniciar Entrega*, el pedido pasa a "En camino" automáticamente.
* **Navegación GPS y Mapas:**
    * Integración de `flutter_map` con trazado OSRM para mostrar la ruta específica calculada desde la posición real del dispositivo hasta la dirección de entrega.
    * **Botón de Google Maps:** Posibilidad de abrir la app nativa de Google Maps pre-cargada con las coordenadas del cliente para asistencia por voz.
* **Cierre de Entrega (Captura de Datos):**
    * Panel en terreno para registrar **Firma Digital del Cliente** en pantalla.
    * Captura de **Evidencia Fotográfica** mediante la cámara del dispositivo.
    * Reporte estructurado de Incidencias (Ej. "Cliente ausente", "Dirección incorrecta").
* **Gestión de Carga (Capacidad Inteligente):**
    * Monitor visual de la capacidad utilizada del camión vs capacidad máxima.
    * Al marcar pedidos como "Entregados", **la carga se libera automáticamente**, mostrando el espacio disponible actual.

---

## Arquitectura y Tecnologías Técnicas

El código está estructurado bajo los más altos estándares de desarrollo móvil en Flutter:

* **Gestión de Estado (Provider):** Separación limpia de la lógica de negocio usando el patrón Provider (`OrderProvider`, `ClientProvider`, `UserProvider`, `VehicleProvider`).
* **Base de Datos Persistente Local (SQLite):** Todo el sistema corre sobre una BDD relacional local con tablas para `orders`, `clients`, `users`, `vehicles` y `audit_logs`. (Versión de esquema: V5).
* **Geocodificación y Mapas:** Dependencias avanzadas como `geolocator`, `geocoding`, `flutter_map` y `latlong2`. Los ruteos consumen la API de Open Source Routing Machine (OSRM).
* **Hardware Nativo:** Uso de `image_picker` para la cámara nativa y `url_launcher` para llamadas telefónicas y Google Maps.
* **Generación de PDFs:** Uso de `pdf` y `printing` para el motor de reportes.
* **Seguridad y Criptografía:** Algoritmos de encriptado (`SecurityService`) implementados para enmascaramiento de RUTs y protección de logs.
* **Diseño UI/UX (Agnóstico):** Implementado con un `AppTheme` centralizado. Paleta de colores consistente, Glassmorphism, y componentes responsivos fluidos y modernos sin depender de plantillas básicas.

---

## Cómo ejecutar el proyecto

1. **Prerequisitos:** SDK de Flutter instalado (>= 3.x), emulador o dispositivo físico conectado por ADB.
2. Clona el repositorio:
   ```bash
   git clone https://github.com/benjaminisaacmiranda/qubico-transportes.git
   ```
3. Instala las dependencias:
   ```bash
   flutter pub get
   ```
4. Compila y corre la aplicación:
   ```bash
   flutter run
   ```
*(Opcional: Si requieres compilar un APK nativo para Android, ejecuta `flutter build apk --release`)*.

---
*Desarrollado para el portafolio de Qúbico Transportes - 2026*

### Librerías y Dependencias

**Principales (Dependencies):**
* `flutter` (sdk: flutter)
* `go_router`: ^14.2.0
* `cupertino_icons`: ^1.0.8
* `sqflite`: ^2.4.2+1
* `sqflite_common_ffi`: ^2.3.4+4
* `path`: ^1.9.1
* `provider`: ^6.1.5+1
* `intl`: ^0.20.2
* `camera`: ^0.12.0+1
* `signature`: ^6.3.0
* `path_provider`: ^2.1.5
* `http`: ^1.6.0
* `connectivity_plus`: ^7.1.1
* `flutter_bloc`: ^9.1.1
* `image_picker`: ^1.2.2
* `image`: ^4.5.4
* `pdf`: ^3.12.0
* `printing`: ^5.14.3
* `geolocator`: ^14.0.2
* `encrypt`: ^5.0.3
* `flutter_map`: ^8.3.0
* `latlong2`: ^0.9.1
* `geocoding`: ^4.0.0
* `url_launcher`: ^6.3.2
* `firebase_core`: ^4.9.0
* `firebase_auth`: ^6.5.1
* `cloud_firestore`: ^6.4.1
* `fl_chart`: ^0.68.0

**Desarrollo (Dev Dependencies):**
* `flutter_test` (sdk: flutter)
* `flutter_lints`: ^6.0.0

### 🔑 Credenciales de Acceso (Firebase / Administración)

Para ingresar a la consola de Firebase del proyecto o realizar pruebas de autenticación con privilegios dentro de la aplicación, puedes utilizar las siguientes credenciales de desarrollo:

* **Correo:** `qubicotrabajo@gmail.com`
* **Contraseña:** `contrasenalol123plop.`
