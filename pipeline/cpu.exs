defmodule Pipeline.CPU do
  use GenServer

  alias Pipeline.Stage.{IF, ID, EX, MEM, WB}
  
  # This convenience function executed in outer context (main app)
  def initialize, do: GenServer.start_link(__MODULE__, self)
  
  # Start each stage on initialization, ensure that everyone started, then run loop
  def init(master) do
    stages = [IF, ID, EX, MEM, WB] |> Enum.map(&(&1.initialize)) |> ensure
    send self, :run
    {:ok, %{master: master, stages: stages, cycle: 0, signal: 1}}
  end
  
  def handle_info(:run, %{stages: stages, signal: signal} = state) do
    state = insp(state)
    
    # Send signal to each stage, wait for responses and determine whether there was end of program
    eop = stages
      |> Enum.map(&call_stage(&1, {:clock, signal}))
      |> Enum.map(&Task.await(&1))
      |> Enum.any?(&(&1 == :end_of_program))

    if eop do
      {:stop, :normal, state}
    else
      send self, :run
      {:noreply, %{state | signal: rem(signal + 1, 2)}}
    end
  end

  # inspect states of stages before start of the cycle
  defp insp(%{stages: stages, signal: signal, cycle: cycle} = state) do
    if signal == 1 do
      [:red, :bright, "Cycle: #{cycle}"]
        |> IO.ANSI.format
        |> IO.puts

      # Ask each task for current status and print the response
      stages
        |> Enum.map(&call_stage(&1, :status))
        |> Enum.map(&Task.await(&1))
        |> IO.puts

      %{state | cycle: cycle + 1}
    else
      state
    end
  end

  # Async-wrapper to send message to server
  defp call_stage stage, msg do
    Task.async fn ->
      GenServer.call(stage, msg)
    end
  end
  
  # makes sure that all stages started successfully
  defp ensure stages do
    {statuses, pids} = stages |> Enum.unzip
    unless Enum.all? statuses, &(&1 == :ok) do
      raise "Stages broken"
    else
      pids
    end
  end
end
