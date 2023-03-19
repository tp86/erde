local C = require('erde.constants')
local clean = require('erde.cli.clean')
local compile = require('erde.cli.compile')
local repl = require('erde.cli.repl')
local run = require('erde.cli.run')
local sourcemap = require('erde.cli.sourcemap')

local utils = require('erde.utils')
local file_exists = utils.file_exists

local cli_utils = require('erde.cli.utils')
local terminate = cli_utils.terminate

C.IS_CLI_RUNTIME = true

local HELP = ([[
Usage: erde [command] [args]

Commands:
   compile                Compile Erde files into Lua.
   clean                  Remove generated Lua files.

Options:
   -h, --help             Show this help message and exit.
   -v, --version          Show version and exit.
   -b, --bitlib <LIB>     Library to use for bit operations.
   -t, --target <TARGET>  Lua target for version compatability.
                          Must be one of: %s

Compile Options:
   -o, --outdir <DIR>     Output directory for compiled files.
   -w, --watch            Watch files and recompile on change.
   -f, --force            Force rewrite existing Lua files with compiled files.
   -p, --print            Print compiled code instead of writing to files.

Examples:
   erde
      Launch the REPL.

   erde my_script.erde
      Run my_script.erde.

   erde compile my_script.erde
      Compile my_script.erde (into my_script.lua).

   erde compile .
      Compile all *.erde files under the current directory.

   erde compile src -o dest
      Compile all *.erde files in src and place the *.lua files under dest.

   erde clean my_script.lua
      Remove my_script.lua if and only if it has been generated by `erde compile`.

   erde clean .
      Remove all generated *.lua files under the current directory.
]]):format(table.concat(C.VALID_LUA_TARGETS, ', '))

local SUBCOMMANDS = {
  compile = true,
  clean = true,
  sourcemap = true,
}

-- -----------------------------------------------------------------------------
-- Main
-- -----------------------------------------------------------------------------

local arg_index, num_args = 1, #arg
local cli, script_args = {}, {}

local function parse_option(label)
  arg_index = arg_index + 1
  local arg_value = arg[arg_index]

  if not arg_value then
    terminate('Missing argument for ' .. label)
  end

  return arg_value
end

while arg_index <= num_args do
  local arg_value = arg[arg_index]

  if cli.script then
    -- Proxy all arguments after the script to the script itself
    -- (same as Lua interpreter behavior)
    table.insert(script_args, arg_value)
  elseif not cli.subcommand and SUBCOMMANDS[arg_value] then
    cli.subcommand = arg_value
  elseif arg_value == '-h' or arg_value == '--help' then
    terminate(HELP, 0)
  elseif arg_value == '-v' or arg_value == '--version' then
    terminate(C.VERSION, 0)
  elseif arg_value == '-w' or arg_value == '--watch' then
    cli.watch = true
  elseif arg_value == '-f' or arg_value == '--force' then
    cli.force = true
  elseif arg_value == '-p' or arg_value == '--print' then
    cli.print_compiled = true
  elseif arg_value == '-t' or arg_value == '--target' then
    C.LUA_TARGET = parse_option(arg_value)
    if not C.VALID_LUA_TARGETS[C.LUA_TARGET] then
      terminate(table.concat({
        'Invalid Lua target: ' .. C.LUA_TARGET,
        'Must be one of: ' .. table.concat(C.VALID_LUA_TARGETS, ', '),
      }, '\n'))
    end
  elseif arg_value == '-o' or arg_value == '--outdir' then
    cli.outdir = parse_option(arg_value)
  elseif arg_value == '-b' or arg_value == '--bitlib' then
    C.BITLIB = parse_option(arg_value)
  elseif arg_value:sub(1, 1) == '-' then
    terminate('Unrecognized option: ' .. arg_value)
  elseif not cli.subcommand and arg_value:match('%.erde$') then
    cli.script = arg_value
    script_args[-arg_index] = 'erde'
    for i = 1, arg_index do
      script_args[-arg_index + i] = arg[i]
    end
  else
    table.insert(cli, arg_value)
  end

  arg_index = arg_index + 1
end

if cli.subcommand == 'compile' then
  compile(cli)
elseif cli.subcommand == 'clean' then
  clean(cli)
elseif cli.subcommand == 'sourcemap' then
  sourcemap(cli)
elseif not cli.script then
  repl(cli)
elseif not file_exists(cli.script) then
  terminate('File does not exist: ' .. cli.script)
else
  run(cli, script_args)
end
