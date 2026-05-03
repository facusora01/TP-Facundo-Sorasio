defmodule CondorDelSurTest do
  use ExUnit.Case

  defp vuelo_base do
    CondorDelSur.Vuelo.new(%{
      id: 1,
      numero_vuelo: "CD-123",
      origen: "Buenos Aires",
      destino: "Bariloche"
    })
  end

  defp vuelo_con_asiento_y_pasajero do
    vuelo =
      vuelo_base()
      |> CondorDelSur.Vuelo.agregar_asiento(%{fila: 1, columna: 1})

    {:ok, pasajero_id, vuelo} =
      CondorDelSur.Vuelo.registrar_pasajero(vuelo, "Pasajero 1")

    {vuelo, pasajero_id}
  end

  test "crea un nuevo vuelo" do
    vuelo = vuelo_base()

    assert vuelo.id == 1
    assert vuelo.numero_vuelo == "CD-123"
    assert vuelo.origen == "Buenos Aires"
    assert vuelo.destino == "Bariloche"
  end

  test "registra un pasajero en el vuelo" do
    vuelo = vuelo_base()

    {:ok, pasajero_id, vuelo} = CondorDelSur.Vuelo.registrar_pasajero(vuelo, "Pasajero 1")

    assert pasajero_id == 1
    assert map_size(vuelo.pasajeros) == 1

    pasajero = Map.get(vuelo.pasajeros, pasajero_id)
    assert pasajero.nombre == "Pasajero 1"
  end

  test "agrega un asiento al vuelo" do
    vuelo = vuelo_base()

    vuelo =
      CondorDelSur.Vuelo.agregar_asiento(vuelo, %{fila: 1, columna: 1})

    assert map_size(vuelo.asientos) == 1
    assert vuelo.siguiente_asiento_id == 2

    asiento = Map.get(vuelo.asientos, 1)
    assert asiento.fila == 1
    assert asiento.columna == 1
    assert asiento.estado == :available
  end

  test "inicia reserva en asiento disponible" do
    {vuelo, pasajero_id} = vuelo_con_asiento_y_pasajero()

    resultado = CondorDelSur.Vuelo.iniciar_reserva(vuelo, pasajero_id, 1)

    assert {:ok, reserva_id, _vuelo} = resultado
    assert is_integer(reserva_id)
  end

  test "falla al iniciar reserva con pasajero inexistente" do
    vuelo = vuelo_base()
      |> CondorDelSur.Vuelo.agregar_asiento(%{fila: 1, columna: 1})

    resultado = CondorDelSur.Vuelo.iniciar_reserva(vuelo, 999, 1)

    assert {:error, :pasajero_no_encontrado} = resultado
  end

  test "falla al iniciar reserva en asiento inexistente" do
    {:ok, pasajero_id, vuelo} = CondorDelSur.Vuelo.registrar_pasajero(vuelo_base(), "Pasajero 1")

    resultado = CondorDelSur.Vuelo.iniciar_reserva(vuelo, pasajero_id, 999)

    assert {:error, :asiento_no_encontrado} = resultado
  end

  test "falla al iniciar reserva en asiento ocupado" do
    vuelo =
      vuelo_base()
      |> CondorDelSur.Vuelo.agregar_asiento(%{fila: 1, columna: 1})

    {:ok, pasajero_id, vuelo} =
      CondorDelSur.Vuelo.registrar_pasajero(vuelo, "Pasajero 1")

    {:ok, otro_pasajero_id, vuelo} =
      CondorDelSur.Vuelo.registrar_pasajero(vuelo, "Pasajero 2")

    {:ok, _reserva_id, vuelo} =
      CondorDelSur.Vuelo.iniciar_reserva(vuelo, pasajero_id, 1)

    resultado = CondorDelSur.Vuelo.iniciar_reserva(vuelo, otro_pasajero_id, 1)

    assert {:error, :asiento_no_disponible} = resultado
  end

  test "impide que un pasajero tenga dos reservas activas" do
    vuelo =
      vuelo_base()
      |> CondorDelSur.Vuelo.agregar_asiento(%{fila: 1, columna: 1})
      |> CondorDelSur.Vuelo.agregar_asiento(%{fila: 1, columna: 2})

    {:ok, pasajero_id, vuelo} =
      CondorDelSur.Vuelo.registrar_pasajero(vuelo, "Pasajero 1")

    {:ok, _reserva_id, vuelo} =
      CondorDelSur.Vuelo.iniciar_reserva(vuelo, pasajero_id, 1)

    resultado =
      CondorDelSur.Vuelo.iniciar_reserva(vuelo, pasajero_id, 2)

    assert {:error, :pasajero_ya_tiene_reserva_activa} = resultado
  end

  test "confirma una reserva pendiente" do
    {vuelo, pasajero_id} =
      vuelo_con_asiento_y_pasajero()

    {:ok, reserva_id, vuelo} =
      CondorDelSur.Vuelo.iniciar_reserva(vuelo, pasajero_id, 1)

    resultado =
      CondorDelSur.Vuelo.confirmar_reserva(vuelo, reserva_id)

    assert {:ok, _vuelo} = resultado
  end

  test "falla al confirmar reserva inexistente" do
    vuelo = vuelo_base()

    resultado = CondorDelSur.Vuelo.confirmar_reserva(vuelo, 999)

    assert {:error, :reserva_no_encontrada} = resultado
  end

  test "cancela una reserva pendiente" do
    {vuelo, pasajero_id} =
      vuelo_con_asiento_y_pasajero()

    {:ok, reserva_id, vuelo} =
      CondorDelSur.Vuelo.iniciar_reserva(vuelo, pasajero_id, 1)

    resultado =
      CondorDelSur.Vuelo.cancelar_reserva(vuelo, reserva_id)

    assert {:ok, _vuelo} = resultado
  end

  test "falla al cancelar reserva confirmada" do
    {vuelo, pasajero_id} =
      vuelo_con_asiento_y_pasajero()

    {:ok, reserva_id, vuelo} =
      CondorDelSur.Vuelo.iniciar_reserva(vuelo, pasajero_id, 1)

    {:ok, vuelo} =
      CondorDelSur.Vuelo.confirmar_reserva(vuelo, reserva_id)

    resultado =
      CondorDelSur.Vuelo.cancelar_reserva(vuelo, reserva_id)

    assert {:error, :reserva_not_pending} = resultado
  end

  test "expira una reserva pendiente" do
    {vuelo, pasajero_id} =
      vuelo_con_asiento_y_pasajero()

    {:ok, reserva_id, vuelo} =
      CondorDelSur.Vuelo.iniciar_reserva(vuelo, pasajero_id, 1)

    resultado =
      CondorDelSur.Vuelo.expirar_reserva(vuelo, reserva_id)

    assert {:ok, _vuelo} = resultado
  end

  test "reserva expirada libera asiento" do
    {vuelo, pasajero_id} =
      vuelo_con_asiento_y_pasajero()

    {:ok, reserva_id, vuelo} =
      CondorDelSur.Vuelo.iniciar_reserva(vuelo, pasajero_id, 1)

    {:ok, vuelo} =
      CondorDelSur.Vuelo.expirar_reserva(vuelo, reserva_id)

    asiento =
      CondorDelSur.Vuelo.obtener_asiento(vuelo, 1)

    assert asiento.estado == :available
    assert asiento.reserva_id == nil
  end

  test "lista asientos disponibles" do
    vuelo =
      vuelo_base()
      |> CondorDelSur.Vuelo.agregar_asiento(%{fila: 1, columna: 1})
      |> CondorDelSur.Vuelo.agregar_asiento(%{fila: 1, columna: 2})

    {:ok, pasajero_id, vuelo} =
      CondorDelSur.Vuelo.registrar_pasajero(vuelo, "Pasajero 1")

    {:ok, _reserva_id, vuelo} =
      CondorDelSur.Vuelo.iniciar_reserva(vuelo, pasajero_id, 1)

    disponibles =
      CondorDelSur.Vuelo.asientos_disponibles(vuelo)

    assert length(disponibles) == 1
    assert hd(disponibles).id == 2
  end

  test "estado de asiento retorna estado correcto" do
    vuelo =
      vuelo_base()
      |> CondorDelSur.Vuelo.agregar_asiento(%{fila: 1, columna: 1})

    {:ok, estado} =
      CondorDelSur.Vuelo.estado_asiento(vuelo, 1)

    assert estado == :available

    {:error, :asiento_no_encontrado} =
      CondorDelSur.Vuelo.estado_asiento(vuelo, 999)
  end
end
