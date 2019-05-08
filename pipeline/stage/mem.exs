defmodule Pipeline.Stage.MEM do
  use GenServer
  use Bitwise

  def initialize, do: GenServer.start_link(__MODULE__, [], name: :mem)
  def init(_args) do
    state = %{
      in: <<0::73>>,
      out: <<0::71>>
    }
    {:ok, state}
  end
  
  # Proxy request to memory, store response if it was mem read
  def handle_call({:clock, 1}, _, %{in: <<mem_ctl::2, ctl::2, alu_res::32, data::32-signed, rw::5>>} = state) do
    if read = mem(mem_ctl, alu_res, data) do
      {:reply, :ok, %{state | out: <<ctl::2, read::32, alu_res::32, rw::5>>}}
    else
      <<_::2, rdata::32, _::37>> = Map.get(state, :out)
      {:reply, :ok, %{state | out: <<ctl::2, rdata::32, alu_res::32, rw::5>>}}
    end
  end

  # Accepting register push from EX stage
  def handle_call({:push_regs, regs}, _caller, state) do
    {:reply, :ok, %{state | in: regs}}
  end

  # Pushing registers to WB stage on 0 clock
  def handle_call({:clock, 0}, _, %{out: regs} = state) do
    GenServer.call(:wb, {:push_regs, regs})
    {:reply, :ok, state}
  end

  # Ask for status
  def handle_call(:status, _, %{out: <<reg_write::1, memto_reg::1, rdata::32, alu_res::32, rw::5>>} = state) do
    diff = GenServer.call(:main_mem, :changes)

    status = """
    #{[:green, :bright, "MEM-stage"] |> IO.ANSI.format}
    Control: RegWrite=#{reg_write}, MemtoReg=#{memto_reg}
    
    LWValue=#{Integer.to_string rdata, 16} ALUResult=#{Integer.to_string alu_res, 16} WriteRegNum=#{rw} 
    MemDiff: #{diff |> Enum.map(fn {addr, val} -> "#{Integer.to_string val, 16} at #{Integer.to_string addr, 16}" end) |> Enum.join(", ")}
    
    """
    {:reply, status, state}
  end

  # Read from Memory
  defp mem(2, addr, _) do
    GenServer.call(:main_mem, {:read, addr})
  end

  # Write to Memory
  defp mem(1, addr, data) do
    GenServer.call(:main_mem, {:write, addr, data &&& 0xFF})
  end
  defp mem(_, _, _), do: nil
end
