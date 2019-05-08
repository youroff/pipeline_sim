defmodule Pipeline.Stage.ID do
  use GenServer

  def initialize, do: GenServer.start_link(__MODULE__, [], name: :id)
  def init(_args) do
    state = %{
      regs: (0..31) |> Enum.map(&(if &1 == 0, do: 0, else: 0x100 + &1)),
      in: <<0::32>>,
      out: <<0::114>>
    }
    {:ok, state}
  end

  # Decodes control signals and data
  def handle_call({:clock, 1}, _, %{regs: regs, in: inst} = state) do
    out = <<control(inst)::8, data(regs, inst)::bitstring>>
    {:reply, :ok, %{state | out: out}}
  end

  # Accepting register push from IF stage
  def handle_call({:push_regs, regs}, _, state) do
    {:reply, :ok, %{state | in: regs}}
  end
  
  # Writing internal register
  def handle_call({:reg_write, reg, val}, _, %{regs: regs} = state) do
    regs = List.replace_at(regs, reg, val)
    {:reply, :ok, %{state | regs: regs}}
  end

  # Pushing registers to EX stage on 0 clock
  def handle_call({:clock, 0}, _caller, %{out: regs} = state) do
    GenServer.call(:ex, {:push_regs, regs})
    {:reply, :ok, state}
  end
  
  # Ask for status
  def handle_call(:status, _, %{regs: regs, out: <<ctl::8, r1::32, r2::32, off::32, wr1::5, wr2::5>>} = state) do
    <<reg_dst::1, alu_op::2, alu_src::1, mem_read::1, mem_write::1, reg_write::1, memto_reg::1>> = <<ctl::8>>
    <<_::26, funct::6>> = <<off::32>>
    regs = regs
      |> Enum.map(&(Integer.to_string &1, 16))
      |> Enum.with_index
      |> Enum.map(fn {val, i} -> "$#{i} = #{val}" end)
      |> Enum.join(" ")
    status = """
    #{[:green, :bright, "ID-stage"] |> IO.ANSI.format}
    Control: RegDst=#{reg_dst}, ALUOp(2)=#{alu_op}, ALUSrc=#{alu_src}, MemRead=#{mem_read},
             MemWrite=#{mem_write}, RegWrite=#{reg_write}, MemtoReg=#{memto_reg}

    ReadReg1Value=#{Integer.to_string r1, 16} ReadReg2Value=#{Integer.to_string r2, 16}
    Offset=#{Integer.to_string off, 16} WriteReg_20_16=#{wr1} WriteReg_15_11=#{wr2} funct=0x#{Integer.to_string funct, 16}
    
    Regs: #{regs}
    
    """
    {:reply, status, state}
  end

  # Control format: RegDst, ALUOp(2), ALUSrc, MemRead, MemWrite, RegWrite, MemtoReg
  # R-instruction
  defp control(<<0::6, _::20, 0::6>>), do: 0 # NOP
  defp control(<<0::6, _::26>>), do: 0b11000010

  # I-instruction
  defp control(<<0x20::6, _::26>>), do: 0b00011011 # lb
  defp control(<<0x28::6, _::26>>), do: 0b00010100 # sb, hard to carry old bits, so X are set to 0
  defp control(_), do: 0 # Unknown Opcode, equal to NOP

  # Retrieving Register values and calculating sign-extension for offset
  defp data(regs, <<_::6, rs::5, rt::5, rd::5, rest::bitstring>>) do
    rs_val = Enum.at(regs, rs)
    rt_val = Enum.at(regs, rt)
    ext = extend(<<rd::5, rest::bitstring>>)
    <<rs_val::32, rt_val::32, ext::32, rt::5, rd::5>>
  end
  
  defp extend(<<offset::16-signed>>), do: offset
end
