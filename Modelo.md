# Modelo del Sistema - Cóndor del Sur


## Estructuras de datos

- `Pasajero`: `{:id, :nombre}`
- `Asiento`: `{:id, :fila, :columna, :estado, :reserva_id}`
- `Reserva`: `{:id, :pasajero_id, :asiento_id, :estado}`
- `Vuelo`: almacena mapas de asientos, reservas, pasajeros e IDs incrementales


## Módulos principales

- `CondorDelSur.Vuelo`: funciones puras para gestionar estado del vuelo
  - `iniciar_reserva/3`: valida pasajero y asiento disponible
  - `confirmar_reserva/2`, `cancelar_reserva/2`, `expirar_reserva/2`
  - `asientos_disponibles/1`, `obtener_asiento/2`

- `CondorDelSur.ServidorVuelo`: proceso genérico con `spawn` + `loop`
  - Mantiene estado inmutable del `Vuelo`
  - Recibe mensajes y ejecuta operaciones serialmente
  - Usa `Process.register/2` para nombrar el proceso globalmente

- `CondorDelSur.ProcesoPasajero`: crea procesos competidores con `spawn_monitor/1`
  - Envían resultado al padre con `send/2`
  - Monitor notifica con `{:DOWN, ...}` si el proceso termina

- `CondorDelSur.ProcesoExpiracion`: espera y expira reservas
  - `Process.sleep/1` + llamada a servidor


## Funciones principales

- `CondorDelSur.Vuelo.new/1`: crea un vuelo nuevo
- `registrar_pasajero/2`: añade un pasajero al vuelo
- `agregar_asiento/2`: añade un asiento disponible
- `iniciar_reserva/3`: intenta reservar un asiento (valida pasajero y disponibilidad)
- `confirmar_reserva/2`: marca una reserva como pagada
- `cancelar_reserva/2`: libera una reserva pendiente
- `expirar_reserva/2`: libera una reserva por timeout
- `asientos_disponibles/1`: lista asientos sin reservar
- `obtener_asiento/2`: obtiene estado de un asiento


## Concurrencia

- **`register`**: da nombre global al proceso servidor
- **`monitor`**: vigila procesos hijos y detecta terminaciones
- **`Serialize`**: cola de mensajes del servidor evita condiciones de carrera
