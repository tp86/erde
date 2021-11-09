-- Explicit import required for helper scripts
local busted = require('busted')
local say = require('say')
local ParserContext = require('erde.ParserContext')
local CompilerContext = require('erde.CompilerContext')
local rules = require('erde.rules')
local utils = require('erde.utils')

-- -----------------------------------------------------------------------------
-- Asserts
-- -----------------------------------------------------------------------------

--
-- has_subtable
--

local function has_subtable(state, args)
  if type(args[1]) ~= 'table' or type(args[2]) ~= 'table' then
    return false
  end

  for key, value in pairs(args[1]) do
    if type(value) == 'table' then
      if not has_subtable(state, { value, args[2][key] }) then
        return false
      end
    elseif value ~= args[2][key] then
      return false
    end
  end

  return true
end

say:set('assertion.has_subtable.positive', '%s \nis not a subtable of\n%s')

busted.assert:register(
  'assertion',
  'has_subtable',
  has_subtable,
  'assertion.has_subtable.positive'
)

--
-- eval
--

local function eval(state, args)
  return utils.deepCompare(args[1], utils.loadLua('return ' .. args[2])())
end

say:set('assertion.eval.positive', 'Eval error. Expected %s, got %s')
busted.assert:register('assertion', 'eval', eval, 'assertion.eval.positive')

--
-- run
--

local function run(state, args)
  return utils.deepCompare(args[1], utils.loadLua(args[2])())
end

say:set('assertion.run.positive', 'Run error. Expected %s, got %s')
busted.assert:register('assertion', 'run', run, 'assertion.run.positive')

-- -----------------------------------------------------------------------------
-- Setup
-- -----------------------------------------------------------------------------

busted.expose('setup', function()
  parserCtx = ParserContext()
  compilerCtx = CompilerContext()

  parse = {}
  compile = {}

  for name, rule in pairs(rules) do
    parse[name] = function(input)
      parserCtx:load(input)
      return parserCtx[name](parserCtx)
    end

    compile[name] = function(input)
      local node = parse[name](input)
      return compilerCtx:compile(node)
    end
  end
end)