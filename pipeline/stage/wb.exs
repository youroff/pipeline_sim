defmodule Pipeline.Stage.WB do
  use GenServer

  def initialize, do: GenServer.start_link(__MODULE__, [], name: :wb)
  def init(_args) do
    state = %{
      in: <<0::71>>
    }
    {:ok, state}
  end
  
  # If WriteReg is 1 perform reg update
  def handle_call({:clock, 1}, _, %{in: <<1::1, memto_reg::1, rdata::32, alu_res::32, rw::5>>} = state) do
    data = if memto_reg == 1, do: rdata, else: alu_res
    GenServer.call(:id, {:reg_write, rw, data})
    {:reply, :ok, state}
  end
  def handle_call({:clock, 1}, _, state), do: {:reply, :ok, state}

  # Accepting register push from EX stage
  def handle_call({:push_regs, regs}, _caller, state) do
    {:reply, :ok, %{state | in: regs}}
  end

  # Doing nothing on 0 clock
  def handle_call({:clock, 0}, _, state), do: {:reply, :ok, state}

  # Ask for status
  def handle_call(:status, _, state) do
    {:reply, "", state}
  end
end
