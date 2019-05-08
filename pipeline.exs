Path.wildcard("pipeline/**/*.exs") |> Enum.map(&Code.require_file/1)
Process.flag(:trap_exit, true)

alias Pipeline.{CPU, InstMem, MainMem}

program = [
  0xa1020000, 0x810AFFFC, 0x00831820, 0x01263820,
  0x01224820, 0x81180000, 0x81510010, 0x00624022,
  0x00000000, 0x00000000, 0x00000000, 0x00000000
]

InstMem.initialize(program)
MainMem.initialize
CPU.initialize

# This waits for EXIT signal from CPU
receive do
  {:EXIT, _, _} -> nil
end
