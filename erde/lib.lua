-- This module contains higher level functions for use either via API or
-- internally (mostly in the CLI).

local C = require('erde.constants')
local compile = require('erde.compile')
local utils = require('erde.utils')

local loadlua = loadstring or load
local unpack = table.unpack or unpack
local native_traceback = debug.traceback

-- https://www.lua.org/manual/5.1/manual.html#pdf-package.loaders
-- https://www.lua.org/manual/5.2/manual.html#pdf-package.searchers
local searchers = package.loaders or package.searchers

local erde_source_id_counter = 1
local erde_source_cache = {}

-- -----------------------------------------------------------------------------
-- Debug
-- -----------------------------------------------------------------------------

local function rewrite(message)
  -- Only rewrite strings! Other thrown values (including nil) do not get source
  -- and line number information added.
  if type(message) ~= 'string' then return message end

  for erde_source_id, compiled_line in message:gmatch('%[string "(__erde_source_%d+__)"]:(%d+)') do
    local erde_source_alias = '[string "(' .. erde_source_id .. ')"]'
    local sourcemap = {}

    -- Use cached alias + sourcemap as a backup if they are not provided
    if erde_source_cache[erde_source_id] then
      erde_source_alias = erde_source_cache[erde_source_id].alias or erde_source_alias
      sourcemap = erde_source_cache[erde_source_id].sourcemap or sourcemap
    end

    message = message:gsub(
      -- Do not use format here! The escaped bracket will interfere with Lua patterns for `string.format`.
      '%[string "' .. erde_source_id .. '"]:' .. compiled_line,
      -- If we have don't have a sourcemap for erde code, we need to indicate that
      -- the error line is for the generated Lua.
      erde_source_alias .. ':' .. (sourcemap and sourcemap[tonumber(compiled_line)]) or ('(lua:%s)'):format(compiled_line)
    )
  end

  -- When compiling, we translate words that are keywords in Lua but not in
  -- Erde. When reporting errors, we need to transform them back.
  message = message:gsub('__ERDE_SUBSTITUTE_([a-zA-Z]+)__', '%1')

  return message
end

local function traceback(arg1, arg2, arg3)
  local stacktrace, level

  -- Follows native_traceback behavior for determining args.
  if type(arg1) == 'thread' then
    level = arg3 or 1
    -- Add an extra level to account for this traceback function itself!
    stacktrace = native_traceback(arg1, arg2, level + 1)
  else
    level = arg2 or 1
    -- Add an extra level to account for this traceback function itself!
    stacktrace = native_traceback(arg1, level + 1)
  end

  if level > -1 and C.IS_CLI_RUNTIME and not C.DEBUG then
    -- Remove following from stack trace caused by the cli:
    --
    -- [C]: in function 'pcall'
    -- erde/cli/run.lua:xxx: in function 'run'
    -- erde/cli/init.lua:xxx: in main chunk
    --
    -- Note, we do not remove the very last line of the stack, this is the C
    -- entry point of the Lua VM.
    local stack = utils.split(stacktrace, '\n')
    local stacklen = #stack
    for i = 1, 3 do table.remove(stack, stacklen - i) end
    stacktrace = table.concat(stack, '\n')
  end

  if not C.DEBUG then
    -- Remove any lines from `__erde_internal_load_source__` calls.
    -- See `__erde_internal_load_source__` for more details.
    stacktrace = stacktrace:gsub(table.concat({
      '[^\n]*\n',
      '[^\n]*__erde_internal_load_source__[^\n]*\n',
      '[^\n]*\n',
    }), '')
  end

  return rewrite(stacktrace)
end

-- -----------------------------------------------------------------------------
-- Source Loaders
-- -----------------------------------------------------------------------------

-- Load a chunk of Erde code. This caches the generated sourcemap / alias
-- (see `erde_source_cache`) so we can fetch them later during error rewrites.
--
-- The alias is _not_ used as the chunkname in the underlying Lua `load`
-- call. Instead, a unique ID is generated and inserted instead. During error
-- rewrites, this ID will be extracted and replaced with the cached alias.
--
-- This function is also given a unique function name so that it is reliably
-- searchable in stacktraces. During stracetrace rewrites (see `traceback`), the
-- presence of this name dictates which lines we need to remove. Otherwise, the
-- resulting stacktraces will include function calls from this file, which will
-- be quite confusing and noisy for the end user.
--
-- IMPORTANT: THIS FUNCTION MUST NOT BE TAIL CALLED NOR DIRECTLY CALLED BY THE
-- USER AND IS ASSUMED TO BE CALLED AT THE TOP LEVEL OF LOADING ERDE SOURCE CODE.
--
-- Although we use a unique name here to find it in stacktraces, the actual
-- rewriting is much trickier. Because Lua will automatically collapse tail
-- calls in stacktraces, its hard to know how many lines of internal code
-- _before_ the call to `__erde_internal_load_source__` we need to remove.
--
-- Furthermore, finding the name of the function call is also nontrivial and
-- will actually get lost if this is directly called by the user, so it must
-- have at least one function call before it (even the Lua docs seem to mention
-- this in `debug.getinfo`, see https://www.lua.org/pil/23.1.html).
--
-- Thus, for consistency we always assume that this is never tail called and
-- it is called at the top level of loading erde source code, which ensures that
-- we always have the following 3 lines to remove:
--
-- 1. The `xpcall` in `__erde_internal_load_source__`
-- 2. The call to `__erde_internal_load_source__` itself
-- 3. The call that invoked `__erde_internal_load_source__`
--
-- Currently there are three ways for the user to load Erde code:
--
-- 1. Via the CLI (ex. `erde myfile.erde`)
-- 2. Via `erde_searcher`
-- 3. Via `run_string`
--
-- Any changes to these functions and their stack calls should be done w/ great
-- precaution.
local function __erde_internal_load_source__(source, alias)
  local erde_source_id = ('__erde_source_%d__'):format(erde_source_id_counter)
  erde_source_id_counter = erde_source_id_counter + 1

  -- No xpcall here, we want the traceback to start from this stack!
  local compiled, sourcemap = compile(source, alias)

  -- TODO: provide an option to disable source maps? Caching them prevents them
  -- from getting freed, and the tables (which may be potentially large) may
  -- have excessive memory usage on extremely constrained systems?
  erde_source_cache[erde_source_id] = { alias = alias, sourcemap = sourcemap }

  -- Remove the shebang! Lua's `load` function cannot handle shebangs.
  compiled = compiled:gsub('^#![^\n]+', '')

  local loader, load_error = loadlua(compiled, erde_source_id)

  if load_error ~= nil then
    error({
      type = 'run',
      message = table.concat({
        'Failed to load compiled code:',
        tostring(load_error),
        '',
        'This is an internal error that should never happen.',
        'Please report this at: https://github.com/erde-lang/erde/issues',
        '',
        'erde',
        '----',
        source,
        '',
        'lua',
        '---',
        compiled,
      }, '\n'),
    })
  end

  return loader()
end

-- IMPORTANT: THIS IS AN ERDE SOURCE LOADER AND MUST ADHERE TO THE USAGE SPEC OF
-- `__erde_internal_load_source__`!
local function run_string(source, alias)
  local result = __erde_internal_load_source__(source, alias)
  return result
end

-- -----------------------------------------------------------------------------
-- Package Loader
-- -----------------------------------------------------------------------------

local function erde_searcher(module)
  local module_path = module:gsub('%.', C.PATH_SEPARATOR)

  for path in package.path:gmatch('[^;]+') do
    local fullpath = path:gsub('%.lua$', '.erde'):gsub('?', module_path)

    if utils.file_exists(fullpath) then
      -- IMPORTANT: THIS IS AN ERDE SOURCE LOADER AND MUST ADHERE TO THE USAGE SPEC OF
      -- `__erde_internal_load_source__`!
      return function()
        local source = utils.read_file(fullpath)
        local result = __erde_internal_load_source__(source, fullpath)
        return result
      end
    end
  end
end

local function load(new_lua_target, options)
  options = options or {}

  if new_lua_target ~= nil then
    if C.VALID_LUA_TARGETS[new_lua_target] then
      C.LUA_TARGET = new_lua_target
    else
      error(table.concat({
        'Invalid Lua target: ' .. new_lua_target,
        'Must be one of: ' .. table.concat(C.VALID_LUA_TARGETS, ', '),
      }, '\n'))
    end
  elseif jit ~= nil then
    C.LUA_TARGET = jit
  else
    new_lua_target = _VERSION:match('Lua (%d%.%d)')
    if C.VALID_LUA_TARGETS[new_lua_target] then
      C.LUA_TARGET = new_lua_target
    end
  end

  if options.bitlib then
    C.BITLIB = options.bitlib
  end

  if options.keep_traceback ~= true then
    -- Override Lua's native traceback with our own to rewrite Erde paths.
    debug.traceback = traceback
  end

  if options.debug == true then
    C.DEBUG = true
  end

  for i, searcher in ipairs(searchers) do
    if searcher == erde_searcher then
      return
    end
  end

  -- We need to place the searcher before the `.lua` searcher to prioritize Erde
  -- modules over Lua modules. If the user has compiled an Erde project before
  -- but the compiled files are out of date, we need to avoid loading the
  -- outdated modules.
  table.insert(searchers, 2, erde_searcher)
end

local function unload()
  -- Restore Lua's native traceback
  debug.traceback = native_traceback

  for i, searcher in ipairs(searchers) do
    if searcher == erde_searcher then
      table.remove(searchers, i)
      return
    end
  end
end

-- -----------------------------------------------------------------------------
-- Return
-- -----------------------------------------------------------------------------

return {
  __erde_internal_load_source__ = __erde_internal_load_source__,
  rewrite = rewrite,
  traceback = traceback,
  run = run_string,
  load = load,
  unload = unload,
}
