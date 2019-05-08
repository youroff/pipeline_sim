defmodule Pipeline.MainMem do
  use GenServer
  use Bitwise, only_operators: true
    
  def initialize, do: GenServer.start_link(__MODULE__, [], name: :main_mem)  
  
  def init(_args) do
    {:ok, %{mem: (0..1023) |> Enum.map(&(&1 &&& 0xFF)), changes: []}}
  end
  
  # Read from memory
  def handle_call({:read, addr}, _, %{mem: mem} = state) do
    {:reply, Enum.at(mem, addr), state}
  end

  # Write to memory
  def handle_call({:write, addr, val}, _, %{mem: mem, changes: changes}) do
    mem = List.replace_at(mem, addr, val)
    changes = [{addr, val} | changes]
    {:reply, nil, %{mem: mem, changes: changes}}
  end

  # Return diff (a history of memory changes)
  def handle_call(:changes, _, %{changes: changes} = state) do
    {:reply, changes, state}
  end
end
