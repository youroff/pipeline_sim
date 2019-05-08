defmodule Pipeline.Stage.EX do
  use GenServer

  def initialize, do: GenServer.start_link(__MODULE__, [], name: :ex)
  def init(_args) do
    state = %{
      in: <<0::114>>,
      out: <<0::73>>
    }
    {:ok, state}
  end
  
  # Run ALU and chose write reg
  def handle_call({:clock, 1}, _, %{in: <<dst::1, op::2, src::1, ctl::4, r1::32, r2::32, rest::32, wregs::10>>} = state) do
    rw = wreg(<<wregs::10>>, dst)
    alu_res = alu(op, src, <<r1::32, r2::32, rest::32>>)
    out = <<ctl::4, alu_res::32, r2::32, rw::5>>
    {:reply, :ok, %{state | out: out}}        
  end

  # Accepting register push from ID stage
  def handle_call({:push_regs, regs}, _caller, state) do
    {:reply, :ok, %{state | in: regs}}
  end

  # Pushing registers to MEM stage on 0 clock
  def handle_call({:clock, 0}, _caller, %{out: regs} = state) do
    GenServer.call(:mem, {:push_regs, regs})
    {:reply, :ok, state}
  end
  
  # Ask for status
  def handle_call(:status, _, %{out: <<mem_read::1, mem_write::1, reg_write::1, memto_reg::1, alu_res::32, val::32, rw::5>>} = state) do
    status = """
    #{[:green, :bright, "EX-stage"] |> IO.ANSI.format}
    Control: MemRead=#{mem_read}, MemWrite=#{mem_write}, RegWrite=#{reg_write}, MemtoReg=#{memto_reg}
    
    ALUResult=#{Integer.to_string alu_res, 16} SWValue=#{Integer.to_string val, 16} WriteRegNum=#{rw} 
    
    """
    {:reply, status, state}
  end
  
  # ALU op matrix
  defp alu(2, 0, <<l::32-signed, r::32-signed, _::26, 0x20::6>>), do: l + r
  defp alu(2, 0, <<l::32-signed, r::32-signed, _::26, 0x22::6>>), do: l - r
  defp alu(0, 1, <<l::32-signed, _::32, r::32-signed>>), do: l + r
  defp alu(_, _, _), do: 0

  defp wreg(<<rd::size(5), _::size(5)>>, 0), do: rd
  defp wreg(<<_::size(5), rt::size(5)>>, 1), do: rt
end
