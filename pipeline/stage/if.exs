defmodule Pipeline.Stage.IF do
  use GenServer

  def initialize, do: GenServer.start_link(__MODULE__, [], name: :if)  
  def init(_args), do: {:ok, %{pc: 0, out: <<0::32>>}}

  # Beginning of cycle: reading the inst or ending the program
  def handle_call({:clock, 1}, _, %{pc: pc}) do
    if inst = GenServer.call(:inst_mem, {:get, pc}) do
      {:reply, :ok, %{pc: pc + 4, out: <<inst::32>>}}        
    else
      {:reply, :end_of_program, %{pc: pc}}
    end
  end

  # Pushing registers to ID stage on 0 clock
  def handle_call({:clock, 0}, _, %{out: regs} = state) do
    GenServer.call(:id, {:push_regs, regs})
    {:reply, :ok, state}
  end
  
  # Ask for status
  def handle_call(:status, _, state) do
    {:reply, status(state), state}
  end

  # Generates status report
  defp status(%{pc: pc, out: <<inst::32>>}) do
    i = Integer.to_string(inst, 16) |> String.pad_leading(8, "0")
    pc = Integer.to_string(pc, 16) |> String.pad_leading(8, "0")
    """
    #{[:green, :bright, "IF-stage"] |> IO.ANSI.format}
    Inst = 0x#{i}  [#{parse(<<inst::32>>)}] IncPC: #{pc}\n
    """
  end
  
  # Inst human-readable decoder matrix
  defp parse(<<0::6, rs::5, rt::5, rd::5, _::5, 0x20::6>>), do: "add $#{rd}, $#{rs}, $#{rt}"
  defp parse(<<0::6, rs::5, rt::5, rd::5, _::5, 0x22::6>>), do: "sub $#{rd}, $#{rs}, $#{rt}"
  defp parse(<<0x20::6, rs::5, rt::5, offset::16-signed>>), do: "lb $#{rt} #{offset}($#{rs})"
  defp parse(<<0x28::6, rs::5, rt::5, offset::16-signed>>), do: "sb $#{rt} #{offset}($#{rs})"
  defp parse(_), do: "NOP"
end
