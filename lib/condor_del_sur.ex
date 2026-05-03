defmodule CondorDelSur.Pasajero do
  defstruct [:id, :nombre]
end


defmodule CondorDelSur.Asiento do
  defstruct [:id, :fila, :columna, estado: :available, reserva_id: nil]
end


defmodule CondorDelSur.Reserva do
  defstruct [:id, :pasajero_id, :asiento_id, estado: :pending]
end


defmodule CondorDelSur.Vuelo do
  defstruct [
    :id,
    :numero_vuelo,
    :origen,
    :destino,
    siguiente_asiento_id: 1,
    siguiente_reserva_id: 1,
    siguiente_pasajero_id: 1,
    asientos: %{},
    reservas: %{},
    pasajeros: %{}
  ]

  def new(attrs), do: struct(__MODULE__, attrs)

  def registrar_pasajero(vuelo, nombre) do
    pasajero = %CondorDelSur.Pasajero{id: vuelo.siguiente_pasajero_id, nombre: nombre}

    vuelo_act = %{
      vuelo
      | siguiente_pasajero_id: vuelo.siguiente_pasajero_id + 1,
        pasajeros: Map.put(vuelo.pasajeros, pasajero.id, pasajero)
    }

    {:ok, pasajero.id, vuelo_act}
  end

  defp pasajero_tiene_reserva_activa?(vuelo, pasajero_id) do
    vuelo.reservas
    |> Map.values()
    |> Enum.any?(fn reserva ->
      reserva.pasajero_id == pasajero_id and reserva.estado in [:pending, :confirmed]
    end)
  end

  def agregar_asiento(vuelo, attrs) do
    asiento = %CondorDelSur.Asiento{
      id: vuelo.siguiente_asiento_id,
      fila: attrs.fila,
      columna: attrs.columna
    }

    %{
      vuelo
      | siguiente_asiento_id: vuelo.siguiente_asiento_id + 1,
        asientos: Map.put(vuelo.asientos, asiento.id, asiento)
    }
  end

  def obtener_asiento(vuelo, asiento_id), do: Map.get(vuelo.asientos, asiento_id)

  def iniciar_reserva(vuelo, pasajero_id, asiento_id) do
    asiento = Map.get(vuelo.asientos, asiento_id)
    pasajero = Map.get(vuelo.pasajeros, pasajero_id)

    cond do
      pasajero == nil ->
        {:error, :pasajero_no_encontrado}

      pasajero_tiene_reserva_activa?(vuelo, pasajero_id) ->
        {:error, :pasajero_ya_tiene_reserva_activa}

      asiento == nil ->
        {:error, :asiento_no_encontrado}

      asiento.estado != :available ->
        {:error, :asiento_no_disponible}

      true ->
        reserva = %CondorDelSur.Reserva{
          id: vuelo.siguiente_reserva_id,
          pasajero_id: pasajero_id,
          asiento_id: asiento_id
        }

        asiento_act = %{asiento | estado: :reserved, reserva_id: reserva.id}

        vuelo_act = %{
          vuelo
          | siguiente_reserva_id: vuelo.siguiente_reserva_id + 1,
            asientos: Map.put(vuelo.asientos, asiento_id, asiento_act),
            reservas: Map.put(vuelo.reservas, reserva.id, reserva)
        }

        {:ok, reserva.id, vuelo_act}
    end
  end

  def confirmar_reserva(vuelo, id), do: cambiar_estado(vuelo, id, :confirmed, :confirmed)

  def cancelar_reserva(vuelo, id), do: cambiar_estado(vuelo, id, :cancelled, :available)

  def expirar_reserva(vuelo, id), do: cambiar_estado(vuelo, id, :expired, :available)

  defp cambiar_estado(vuelo, reserva_id, est_reserva, est_asiento) do
    reserva = Map.get(vuelo.reservas, reserva_id)

    cond do
      reserva == nil ->
        {:error, :reserva_no_encontrada}

      reserva.estado != :pending ->
        {:error, :reserva_not_pending}

      true ->
        reserva_act = %{reserva | estado: est_reserva}

        res_id_para_asiento = if est_asiento == :available, do: nil, else: reserva.id

        asiento_act = %{
          Map.get(vuelo.asientos, reserva.asiento_id)
          | estado: est_asiento,
            reserva_id: res_id_para_asiento
        }

        {
          :ok,
          %{
            vuelo
            | reservas: Map.put(vuelo.reservas, reserva_id, reserva_act),
              asientos: Map.put(vuelo.asientos, reserva.asiento_id, asiento_act)
          }
        }
    end
  end

  def asientos_disponibles(vuelo) do
    vuelo.asientos
    |> Map.values()
    |> Enum.filter(&(&1.estado == :available))
  end

  def estado_asiento(vuelo, asiento_id) do
    case Map.get(vuelo.asientos, asiento_id) do
      nil ->
        {:error, :asiento_no_encontrado}

      asiento ->
        {:ok, asiento.estado}
    end
  end
end


defmodule CondorDelSur.ServidorVuelo do
  def iniciar(vuelo) do
    pid = spawn(fn -> loop(vuelo) end)
    Process.register(pid, :servidor_vuelo)
    pid
  end

  defp call(mensaje) do
    send(:servidor_vuelo, {mensaje, self()})

    receive do
      {:respuesta, resultado} ->
        resultado

    after
      5_000 ->
        {:error, :timeout}
    end
  end

  def agregar_asiento(attrs), do: call({:agregar_asiento, attrs})

  def registrar_pasajero(nombre), do: call({:registrar_pasajero, nombre})

  def obtener_asiento(id), do: call({:obtener_asiento, id})

  def iniciar_reserva(p_id, a_id), do: call({:iniciar_reserva, p_id, a_id})

  def confirmar_reserva(id), do: call({:confirmar_reserva, id})

  def cancelar_reserva(id), do: call({:cancelar_reserva, id})

  def expirar_reserva(id), do: call({:expirar_reserva, id})

  def asientos_disponibles(), do: call(:asientos_disponibles)

  def obtener_estado(), do: call(:obtener_estado)

  defp loop(vuelo) do
    receive do
      {{:agregar_asiento, attrs}, caller} ->
        send(caller, {:respuesta, :ok})
        loop(CondorDelSur.Vuelo.agregar_asiento(vuelo, attrs))

      {{:registrar_pasajero, nombre}, caller} ->
        {:ok, p_id, nuevo_vuelo} = CondorDelSur.Vuelo.registrar_pasajero(vuelo, nombre)
        send(caller, {:respuesta, {:ok, p_id}})
        loop(nuevo_vuelo)

      {{:obtener_asiento, id}, caller} ->
        send(caller, {:respuesta, CondorDelSur.Vuelo.obtener_asiento(vuelo, id)})
        loop(vuelo)

      {{:iniciar_reserva, p_id, a_id}, caller} ->
        case CondorDelSur.Vuelo.iniciar_reserva(vuelo, p_id, a_id) do
          {:ok, r_id, nuevo_vuelo} ->
            send(caller, {:respuesta, {:ok, r_id}})
            loop(nuevo_vuelo)

          {:error, razon} ->
            send(caller, {:respuesta, {:error, razon}})
            loop(vuelo)
        end

      {{accion, id}, caller} when accion in [:confirmar_reserva, :cancelar_reserva, :expirar_reserva] ->
        case apply(CondorDelSur.Vuelo, accion, [vuelo, id]) do
          {:ok, nuevo_vuelo} ->
            send(caller, {:respuesta, :ok})
            loop(nuevo_vuelo)

          {:error, razon} ->
            send(caller, {:respuesta, {:error, razon}})
            loop(vuelo)
        end

      {:asientos_disponibles, caller} ->
        send(caller, {:respuesta, CondorDelSur.Vuelo.asientos_disponibles(vuelo)})
        loop(vuelo)

      {:obtener_estado, caller} ->
        send(caller, {:respuesta, vuelo})
        loop(vuelo)
    end
  end
end


defmodule CondorDelSur.ProcesoPasajero do
  def iniciar_con_monitor(pasajero_id, asiento_id, padre) do
    {pid, _ref} =
      spawn_monitor(fn ->
        res = CondorDelSur.ServidorVuelo.iniciar_reserva(pasajero_id, asiento_id)
        send(padre, {:pasajero_resultado, pasajero_id, res})
      end)

    pid
  end
end


defmodule CondorDelSur.ProcesoExpiracion do
  def iniciar(reserva_id, timeout_ms \\ 3000) do
    spawn(fn ->
      Process.sleep(timeout_ms)
      CondorDelSur.ServidorVuelo.expirar_reserva(reserva_id)
    end)
  end
end


defmodule CondorDelSur.Demo do
  def ejecutar do
    IO.puts("\n=== Cóndor del Sur - Demo ===")

    vuelo =
      CondorDelSur.Vuelo.new(%{id: 1, numero_vuelo: "CD-123", origen: "BUE", destino: "BRC"})

    CondorDelSur.ServidorVuelo.iniciar(vuelo)

    Enum.each(1..3, fn col ->
      CondorDelSur.ServidorVuelo.agregar_asiento(%{fila: 1, columna: col})
    end)

    Enum.each(1..5, fn i ->
      CondorDelSur.ServidorVuelo.registrar_pasajero("Pasajero #{i}")
    end)

    IO.puts("Vuelo inicializado con 3 asientos y 5 pasajeros registrados.\n")

    IO.puts("1. Competencia concurrente por el Asiento 1")

    padre = self()

    Enum.each(1..5, fn pid ->
      CondorDelSur.ProcesoPasajero.iniciar_con_monitor(pid, 1, padre)
    end)

    Enum.each(1..10, fn _ ->
      receive do
        {:pasajero_resultado, pid, res} ->
          IO.puts("  Pasajero #{pid} intentó reservar: #{inspect(res)}")

        {:DOWN, _ref, :process, pid, reason} ->
          IO.puts("  [Monitor] El proceso del pasajero #{inspect(pid)} finalizó (#{inspect(reason)})")
      end
    end)

    IO.puts("\n2. Confirmación (Asiento 2) y Cancelación (Asiento 3)")

    {:ok, pasajero_6} = CondorDelSur.ServidorVuelo.registrar_pasajero("Pasajero 6")
    {:ok, res_2} = CondorDelSur.ServidorVuelo.iniciar_reserva(pasajero_6, 2)
    CondorDelSur.ServidorVuelo.confirmar_reserva(res_2)
    IO.puts("  Reserva #{res_2} pagada y confirmada.")

    {:ok, pasajero_7} = CondorDelSur.ServidorVuelo.registrar_pasajero("Pasajero 7")
    {:ok, res_3} = CondorDelSur.ServidorVuelo.iniciar_reserva(pasajero_7, 3)
    CondorDelSur.ServidorVuelo.cancelar_reserva(res_3)
    IO.puts("  Reserva #{res_3} cancelada por el usuario.")

    IO.puts("\n3. Expiración de Reserva (Tarea auxiliar en Asiento 3 liberado)")

    {:ok, pasajero_8} = CondorDelSur.ServidorVuelo.registrar_pasajero("Pasajero 8")
    {:ok, res_4} = CondorDelSur.ServidorVuelo.iniciar_reserva(pasajero_8, 3)
    CondorDelSur.ProcesoExpiracion.iniciar(res_4, 1500)
    IO.puts("  Reserva #{res_4} iniciada. Esperando 2 segundos para que la tarea auxiliar la expire...")
    Process.sleep(2000)

    IO.puts("\n=== Estado Final ===")

    estado = CondorDelSur.ServidorVuelo.obtener_estado()
    disponibles = CondorDelSur.Vuelo.asientos_disponibles(estado)

    IO.puts("Asientos disponibles: #{length(disponibles)} (Debería ser 1, el asiento 3 que expiró)")
    IO.puts("Reservas totales registradas en historial: #{map_size(estado.reservas)}")
  end
end
