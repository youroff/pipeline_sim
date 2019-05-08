defmodule Pipeline.InstMem do
  use GenServer
  
  def initialize(program), do: GenServer.start_link(__MODULE__, program, name: :inst_mem)  
  def init(program) do
    {:ok, program}
  end
  
  # Get instruction by PC
  def handle_call({:get, pc}, _caller, program) do
    {:reply, Enum.at(program, div(pc, 4)), program}
  end
end