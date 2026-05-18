1. Dashboard Principal: Centro de Control en Tiempo Real
  Componentes Visuales:
    Tarjetas de Resumen (Top):
      KPI de Puntualidad Mensual: Gráfico de medidor (gauge) que muestra el porcentaje de entregas a tiempo.
      Estado de la Flota: Contador dinámico (ej: 4/5 Camionetas en ruta).

    Mapa Interactivo (Centro):
      Integración con Google Maps API mostrando marcadores de colores según el estado del vehículo (Verde: Entregando, Azul: En camino, Gris: Disponible).

    Panel de Alertas Críticas (Derecha):
      Lista con fondo Rojo suave que resalta pedidos con más de 15 minutos de atraso respecto a su ventana horaria.

2. Módulo de Gestión de Pedidos: Ingreso y Edición
  Diseñado para que el personal de Staff complete el registro en menos de 30 minutos.
  Formulario de "Nuevo Despacho" (RF1, RF2, RF3):
    Campo / Tipo de Control / Validación o Regla
    Cliente / Buscador o Dropdown / Debe estar registrado previamente
    RUT / texto / Validación formato chileno
    Peso (kg) / Númerico / Bloqueo si excede la capacidad máxima de la camioneta
    Dimensiones (cm) /3 campos (Alto, Largo, Ancho) / Valores atómicos para cálculo de carga.
    Tipo de Carga / Dropdown / Opciones: Paquetería, Construcción o Eventos.
    Ventana Horaria / Selector de Bloque / Obligatorio: Bloques horarios predefinidos
  
  Nota de Usabilidad (RNF4): Si el usuario intenta guardar una carga de 1500 kg en un vehículo de 1000 kg, el sistema debe mostrar un mensaje: "Error: El peso ingresado (1500kg) supera la capacidad máxima del vehículo asignado (1000kg)"

3. Asignación de Rutas y Algoritmo FIFO
Esta sección gestiona la lógica de despacho antes de que la información viaje a la App del conductor.

Buscador de Conductores (RF4): Filtra automáticamente la lista mostrando solo personal con:
  Estado "Activo".  
  En horario laboral actual.  
  Licencia de conducir vigente.  
Vista de Pre-Ordenamiento (RF6): Antes de confirmar la ruta, el administrador ve la lista ordenada por la hora de inicio de la ventana.
  En caso de empate horario, se aplica la regla FIFO:
    Prioridad = min(Hora\_Inicio, Fecha\_Registro)

4. Control de Gestión y Reportabilidad
El núcleo de la inteligencia de negocios para Qúbico.

  Cálculo Automático de Puntualidad (RF13): El sistema procesa la diferencia entre la captura de evidencia y el compromiso horario:
    $$Indicador = Hora\_Real\_Entrega - Hora\_Fin\_Ventana$$

  Generador de Reportes (RF14.1, RF14.2):
    Botón PDF: Historial de servicio para entrega al cliente.
    Botón Excel: Datos en bruto (RUT, peso, estado) para análisis contable.
  Reporte Nocturno (RF12): Configuración de envío automático al correo del administrador cada día a las 20:00 hrs.

5. Configuración de Seguridad y Perfiles (HU05)
Interfaz de administración de usuarios y auditoría.

  Gestión de Cuentas: Tabla con opción de Desactivación Lógica. No se borran filas de la base de datos para no romper la integridad de los reportes históricos.  
  Reglas de Acceso (RNF11): Al crear un usuario nuevo, el sistema fuerza una contraseña de 8 caracteres con al menos una mayúscula y un número.  
  Bitácora de Auditoría (RNF15): Vista de solo lectura que detalla:
    "El usuario [Admin_Luis] modificó el [Estado_Pedido] del ID #450 de [Pendiente] a [Anulado] el día 18/05/2026 a las 14:00 hrs".
  
Resumen de Estética Visual (RNF3, RNF8):
Fondo: Gris muy claro para evitar fatiga visual.
Botones de Acción: Naranja vibrante para "Guardar" o "Asignar".  
Mensajes de Error: Aparecen sobre el campo afectado en color rojo con lenguaje no técnico.