local compile = require('erde.compile')
local config = require('erde.config')
local lib = require('erde.lib')

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------

local function assert_eval(expected, source)
  if expected == nil then
    assert.is_nil(lib.run('return ' .. source))
  else
    assert.are.same(expected, lib.run('return ' .. source))
  end
end

local function assert_run(expected, source)
  if expected == nil then
    assert.is_nil(lib.run(source))
  else
    assert.are.same(expected, lib.run(source))
  end
end

-- -----------------------------------------------------------------------------
-- Expressions
-- -----------------------------------------------------------------------------

describe('arrow function #5.1+', function()
  spec('params', function()
    assert_run(1, [[
      local a = (x) -> x
      return a(1)
    ]])
    assert_run(3, [[
      local a = (x, y = 2) -> x + y
      return a(1)
    ]])
    assert_run(3, [[
      local a = (x = 3, y) -> x + y
      return a(1, 2)
    ]])
    assert_run({ 1, 2 }, [[
      local a = (...) -> ({ ... })
      return a(1, 2)
    ]])
    assert_run({ 2, 3 }, [[
      local a = (x, ...) -> ({ ... })
      return a(1, 2, 3)
    ]])
    assert_run({ 1, 2 }, [[
      local a = (...x) -> x
      return a(1, 2)
    ]])
    assert_run({ 2, 3 }, [[
      local a = (x, ...y) -> y
      return a(1, 2, 3)
    ]])
    assert_run({ 1, 2, { 3, 4 } }, [[
      local a = (x, y = 2, ...) -> ({ x, y, { ... } })
      return a(1, 2, 3, 4)
    ]])
    assert_run({ 1, 2, { 3, 4 } }, [[
      local a = (x, y = 2, ...z) -> ({ x, y, z })
      return a(1, 2, 3, 4)
    ]])
    assert_run(2, [[
      local a = x -> x + 1
      return a(1)
    ]])
    assert_run(2, [[
      local a = [ x ] -> x + 1
      return a({ 1 })
    ]])
    assert_run(2, [[
      local a = { x } -> x + 1
      return a({ x = 1 })
    ]])
    assert.has_error(function()
      compile('local a = x = 2 -> x')
    end)
    assert.has_error(function()
      compile('local a = x -> { x }')
    end)
  end)

  spec('implicit return', function()
    assert_run(1, [[
      local a = () -> 1
      return a()
    ]])
    assert_run(1, [[
      local a = (x) -> x
      return a(1)
    ]])
    assert_run(3, [[
      local a = (x, y) -> x + y
      return a(1, 2)
    ]])
    assert_run({ 1, 2 }, [[
      local a = (x, y) -> ({ x, y })
      return a(1, 2)
    ]])
    assert_run(3, [[
      local a = () -> (1, 2)
      local b, c = a()
      return b + c
    ]])
    assert_run(1, [[
      local a = x -> ({ x = x }).x
      return a(1)
    ]])
  end)

  spec('skinny', function()
    assert_eval('function', 'type(() -> {})')
    assert_run(1, [[
      local a = () -> { return 1 }
      return a()
    ]])
    assert_run(1, [[
      local a = x -> { return x }
      return a(1)
    ]])
    assert_run(1, [[
      local a = x -> { return x }
      return a(1)
    ]])
    local sum = lib.run('return (a, b) -> a + b')
    assert.are.equal(3, sum(1, 2))
  end)

  spec('fat', function()
    assert_eval('function', 'type(() => {})')
    assert_run(1, [[
      local a = { b = 1 }
      a.c = () => { return self.b }
      return a:c()
    ]])
    assert_run(3, [[
      local a = { b = 1 }
      a.c = x => { return self.b + x }
      return a:c(2)
    ]])
    local sum = lib.run('return (a, b) => a + b + self.c')
    assert.are.equal(6, sum({ c = 3 }, 1, 2))
  end)

  spec('iife', function()
    assert_eval(1, '(() -> { return 1 })()')
    assert_eval(1, '(() -> 1)()')
  end)
end)

describe('index chain #5.1+', function()
  spec('dot', function()
    assert_eval(1, '({ x = 1 }).x')
    assert_run(1, [[
      local a = { b = 1 }
      return a.b
    ]])
  end)

  spec('bracket', function()
    assert_eval(2, '({ 2 })[1]')
    assert_run(1, [[
      local a = { [5] = 1 }
      return a[2 + 3]
    ]])
  end)

  spec('function call', function()
    assert_run(3, [[
      local a = (x, y) -> x + y
      return a(1, 2)
    ]])
  end)

  spec('method call', function()
    assert_run(3, [[
      local a = {
        b = (self, x) -> self.c + x,
        c = 1,
      }
      return a:b(2)
    ]])
    assert.has_error(function()
      compile('a:b')
    end)
  end)

  spec('chain', function()
    assert_run(2, [[
      local a = { b = { 2 } }
      return a.b[1]
    ]])
    assert_run(2, [[
      local a = { { b = 2 } }
      return a[1].b
    ]])
  end)

  spec('nested parens', function()
    assert_eval(1, '((({ x = 1 }))).x')
  end)

  spec('string base', function()
    assert_eval('yourstring', '"mystring":gsub("my", "your")')
    assert_eval('yourstring', "'mystring':gsub('my', 'your')")
    assert_eval('yourstring', "[[mystring]]:gsub('my', 'your')")
  end)
end)

describe('strings #5.1+', function()
  spec('single quote', function()
    assert_eval('', "''")
    assert_eval('hello', "'hello'")
    assert_eval('hello\nworld', "'hello\\nworld'")
    assert_eval('\\', "'\\\\'")
  end)

  spec('double quote', function()
    assert_eval('', '""')
    assert_eval('hello', '"hello"')
    assert_eval('hello\nworld', '"hello\\nworld"')
    assert_eval('\\', '"\\\\"')
  end)

  spec('block', function()
    assert_eval('hello world', '[[hello world]]')
    assert_eval(' hello\nworld', '[[ hello\nworld]]')
    assert_eval('a{bc}d', '[[a\\{bc}d]]')
    assert_eval('a[[b', '[=[a[[b]=]')
    assert_eval('a', '[[\na]]')
    assert_eval('3\na', '[[{1 + 2}\na]]')
  end)

  spec('interpolation', function()
    assert_eval('hello {1 + 2}', "'hello {1 + 2}'")
    assert_eval('hello 3', '"hello {1 + 2}"')
    assert_eval('hello 3', '[[hello {1 + 2}]]')
  end)
end)

spec('tables #5.1+', function()
  assert_eval({ 10 }, '{ 10 }')
  assert_eval({ x = 2 }, '{ x = 2 }')
  assert_eval({ [3] = 1 }, '{ [1 + 2] = 1 }')
  assert_eval({ x = { y = 1 } }, '{ x = { y = 1 } }')
end)

describe('unop', function()
  spec('arithmetic ops #5.1+', function()
    assert_eval(-6, '-6')
    assert_eval(5, '#("hello")')
    assert_eval(false, '!true')
  end)

  if config.lua_target == '5.1+' or config.lua_target == '5.2+' then
    spec('bitops', function()
      assert.has_error(function() compile('print(~4)') end)
    end)
  else
    spec('bitops', function()
      assert_eval(-5, '~4')
    end)
  end
end)

describe('binop #5.1+', function()
  spec('arithmetic ops', function()
    assert_eval(-6, '2 * -3')
    assert_eval(-6, '-2 * 3')
    assert_eval(-8, '-2 ^ 3')
  end)

  if config.lua_target == '5.1+' or config.lua_target == '5.2+' then
    spec('bitops', function()
      assert.has_error(function() compile('print(4 | 2)') end)
      assert.has_error(function() compile('print(6 ~ 3)') end)
      assert.has_error(function() compile('print(6 & 3)') end)
      assert.has_error(function() compile('print(1 << 1)') end)
      assert.has_error(function() compile('print(2 >> 1)') end)
    end)
  else
    spec('bitops', function()
      assert_eval(6, '4 | 2')
      assert_eval(5, '6 ~ 3')
      assert_eval(2, '6 & 3')
      assert_eval(2, '1 << 1')
      assert_eval(1, '2 >> 1')
    end)
  end

  spec('left associative', function()
    assert_eval(5, '1 * 2 + 3')
    assert_eval(7, '1 + 2 * 3')
    assert_eval(11, '1 + 2 * 3 + 4')
  end)

  spec('right associative', function()
    assert_eval(512, '2 ^ 3 ^ 2')
    assert_eval(7, '2 ^ 2 + 3')
  end)

  spec('parens', function()
    assert_eval(25, '5 * (2 + 3)')
  end)
end)

-- -----------------------------------------------------------------------------
-- Statements
-- -----------------------------------------------------------------------------

spec('assignment #5.1+', function()
  assert_run(1, [[
    local a
    a = 1
    return a
  ]])
  assert_run(1, [[
    local a = {}
    a.b = 1
    return a.b
  ]])
  assert_run(3, [[
    local a, b
    a, b = 1, 2
    return a + b
  ]])
  assert_run(3, [[
    local a, b = {}, {}
    a.c, b.d = 1, 2
    return a.c + b.d
  ]])
  assert_run(3, [[
    local a = 1
    a += 2
    return a
  ]])
  assert_run(8, [[
    local a, b = 1, 2
    a, b += 2, 3
    return a + b
  ]])
  assert_run({ 1, 2 }, [[
    local function test() { return 1, 2 }
    local x, y = 0, 0
    x, y += test()
    return { x, y }
  ]])
  assert_run({ 1, 2, 3 }, [[
    local function test() { return 2, 3 }
    local x, y, z = 0, 0, 0
    x, y, z += 1, test()
    return { x, y, z }
  ]])
end)

spec('break #5.1+', function()
  assert_run(6, [[
    local x = 0
    while x < 10 {
      x += 2
      if x > 4 {
        break
      }
    }
    return x
  ]])
  assert_run(100, [[
    local x = 0
    for i = 1, 10 {
      for j = 1, 10 {
        if j > 4 {
          break
        }
        x += j
      }
    }
    return x
  ]])
end)

spec('continue #5.1+', function()
  assert_run(30, [[
    local x = 0
    for i = 1, 10 {
      if i % 2 == 1 {
        continue
      }
      x += i
    }
    return x
  ]])
  assert_run(250, [[
    local x = 0
    for i = 1, 10 {
      for j = 1, 10 {
        if j % 2 == 0 {
          continue
        }
        x += j
      }
    }
    return x
  ]])
end)

describe('declaration #5.1+', function()
  spec('local', function()
    assert_run(1, [[
      local a = 1
      return a
    ]])
    assert_run(1, [[
      local a = { x = 1 }
      local { x } = a
      return x
    ]])
    assert_run('hello', [[
      local a = { 'hello', 'world' }
      local [ hello ] = a
      return hello
    ]])
    assert_run(3, [[
      local a, b = 1, 2
      return a + b
    ]])
  end)

  spec('global', function()
    assert_run(1, [[
      global a = 1
      local result = _G.a
      _G.a = nil
      return result
    ]])
    assert_run(1, [[
      local a = 1
      global a = 2
      local result = a
      _G.a = nil
      return result
    ]])
    assert_run(2, [[
      local a = 1
      global a = 2
      local result = _G.a
      _G.a = nil
      return result
    ]])
    assert_run(1, [[
      local a = { x = 1 }
      global { x } = a
      local result = _G.x
      _G.x = nil
      return result
    ]])
    assert_run('hello', [[
      local a = { 'hello', 'world' }
      global [ hello ] = a
      local result = _G.hello
      _G.hello = nil
      return result
    ]])
    assert_run(1, [[
      local a = { 'hello', 'world' }
      global b, [ hello ] = 1, a
      local result = _G.b
      _G.b = nil
      _G.hello = nil
      return result
    ]])
  end)

  spec('module', function()
    assert_run({ a = 1 }, 'module a = 1')
    assert_run({ b = 1 }, [[
      local a = { b = 1 }
      module { b } = a
    ]])
    assert_run({ x = 1 }, [[
      local a = { x = 1 }
      module { x } = a
    ]])
    assert_run({ hello = 'hello' }, [[
      local a = { 'hello', 'world' }
      module [ hello ] = a
    ]])
  end)
end)

spec('do block #5.1+', function()
  assert_run(1, [[
    local x
    do {
      x = 1
    }
    return x
  ]])
  assert_run(nil, [[
    do {
      local x
      x = 1
    }
    return x
  ]])
end)

describe('for loop #5.1+', function()
  spec('numeric', function()
    assert_run(10, [[
      local x = 0
      for i = 1, 4 {
        x += i
      }
      return x
    ]])
    assert_run(4, [[
      local x = 0
      for i = 1, 4, 2 {
        x += i
      }
      return x
    ]])
  end)
  spec('generic', function()
    assert_run(10, [[
      local x = 0
      for i, value in ipairs({ 1, 2, 8, 1 }) {
        x += i
      }
      return x
    ]])
    assert_run(12, [[
      local x = 0
      for i, value in ipairs({ 1, 2, 8, 1 }) {
        x += value
      }
      return x
    ]])
    assert_run(11, [[
      local x = 0
      for i, [a, b] in ipairs({{5, 6}}) {
        x += a + b
      }
      return x
    ]])
  end)
end)

describe('function declaration #5.1+', function()
  spec('params', function()
    assert_run(1, [[
      local function a(x) {
        return x
      }
      return a(1)
    ]])
    assert_run(3, [[
      local function a(x, y = 2) {
        return x + y
      }
      return a(1)
    ]])
    assert_run(3, [[
      local function a(x = 3, y) {
        return x + y
      }
      return a(1, 2)
    ]])
    assert_run({ 1, 2 }, [[
      local function a(...) {
        return { ... }
      }
      return a(1, 2)
    ]])
    assert_run({ 2, 3 }, [[
      local function a(x, ...) {
        return { ... }
      }
      return a(1, 2, 3)
    ]])
    assert_run({ 1, 2 }, [[
      local function a(...x) {
        return x
      }
      return a(1, 2)
    ]])
    assert_run({ 2, 3 }, [[
      local function a(x, ...y) {
        return y
      }
      return a(1, 2, 3)
    ]])
    assert_run({ 1, 2, { 3, 4 } }, [[
      local function a(x, y = 2, ...) {
        return { x, y, { ... } }
      }
      return a(1, 2, 3, 4)
    ]])
    assert_run({ 1, 2, { 3, 4 } }, [[
      local function a(x, y = 2, ...z) {
        return { x, y, z }
      }
      return a(1, 2, 3, 4)
    ]])
    assert_run(2, [[
      local function a([ x ]) {
        return x + 1
      }
      return a({ 1 })
    ]])
    assert_run(2, [[
      local function a({ x }) {
        return x + 1
      }
      return a({ x = 1 })
    ]])
  end)

  spec('local', function()
    assert_run(2, [[
      local function test() {
        return 2
      }

      do {
        local function test() {
          return 1
        }
      }

      return test()
    ]])
    assert_run(1, [[
      local function test() {
        return 2
      }

      do {
        function test() {
          return 1
        }
      }

      return test()
    ]])
    assert.has_error(function()
      compile('local function a.b() {}')
    end)
  end)

  spec('global', function()
    assert_run(2, [[
      local function test() {
        return 2
      }

      do {
        global function test() {
          return 1
        }
      }

      local result = test()
      _G.test = nil
      return result
    ]])
    assert_run(1, [[
      local function test() {
        return 2
      }

      do {
        global function test() {
          return 1
        }
      }

      local result = _G.test()
      _G.test = nil
      return result
    ]])
  end)

  spec('module', function()
    local testModule = lib.run([[
      module function test() {
        return 1
      }
    ]])
    assert.are.equal(1, testModule.test())
    assert.has_error(function()
      compile('module function a.b() {}')
    end)
  end)

  spec('method', function()
    assert_run(1, [[
      local a = { x = 1 }

      function a:test() {
        return self.x
      }

      return a:test()
    ]])
  end)
end)

spec('goto #jit #5.2+', function()
  assert_run(1, [[
    local x
    x = 1
    goto test
    x = 2
    ::test::
    return x
  ]])
end)

describe('if else #5.1+', function()
  spec('if', function()
    assert_run(1, 'if true { return 1 }')
    assert_run(nil, 'if false { return 1 }')
  end)

  spec('if + elseif', function()
    assert_run(2, [[
      if false {
        return 1
      } elseif true {
        return 2
      }
    ]])
  end)

  spec('if + else', function()
    assert_run(2, [[
      if false {
        return 1
      } else {
        return 2
      }
    ]])
  end)

  spec('if + elseif + else', function()
    assert_run(2, [[
      if false {
        return 1
      } elseif true {
        return 2
      } else {
        return 3
      }
    ]])
    assert_run(3, [[
      if false {
        return 1
      } elseif false {
        return 2
      } else {
        return 3
      }
    ]])
  end)
end)

spec('repeat until #5.1+', function()
  assert_run(12, [[
    local x = 0
    repeat {
      x += 2
    } until x > 10
    return x
  ]])
end)

spec('return #5.1+', function()
  assert_run(nil, 'return')
  assert_run(1, 'return 1')
  assert_run(1, 'return (1, 2)')
  assert_run(1, [[
    return (
      1,
      2,
    )
  ]])
  assert.has_error(function()
    compile('return 1 if true {}')
  end)
  assert.has_error(function()
    compile([[
      if true {
        return 1
        print(32)
      }
    ]])
  end)
end)

spec('while loop  #5.1+', function()
  assert_run(10, [[
    local x = 0
    while x < 10 {
      x += 2
    }
    return x
  ]])
end)

-- -----------------------------------------------------------------------------
-- Misc
-- -----------------------------------------------------------------------------

spec('ambiguous syntax #5.1+', function()
  assert_run(1, [[
    local a = 1
    local x = a;(() -> 2)()
    return x
  ]])
  assert_run(1, [[
    local a = 1
    local x = a
    (() -> 2)()
    return x
  ]])
  assert_run(2, [[
    local a = f -> f
    local x = a(() -> 2)()
    return x
  ]])
  assert_run(1, [[
    local a = 1
    local b = a
    (() -> { local c = 2 })()
    return b
  ]])
end)

spec('no varargs outside vararg function #5.1+', function()
  assert.has_error(function()
    compile('local x = () -> { print(...) }')
  end)
  assert.has_error(function()
    compile('local x = () -> ({ ... })')
  end)
  assert.has_error(function()
    compile('function x() { print(...) }')
  end)
  assert.has_no.errors(function()
    compile('print(...)') -- varargs allowed at top level in Lua!
  end)
end)

spec('retain throwaway parens #5.1+', function()
  assert_run(true, [[
    local a = () -> (1, 2)
    local x, y = (a())
    return x == 1
  ]])
  assert_run(false, [[
    local a = () -> (1, 2)
    local x, y = (a())
    return y == 2
  ]])
end)

spec('_MODULE #5.1+', function()
  assert_run(nil, [[ return _MODULE ]])
  assert_run({ x = 1, y = 2 }, [[
    module y = 2
    _MODULE.x = 1
  ]])
end)

spec('Lua keywords that are not Erde keywords #5.1+', function()
  assert_run(1, [[
    local end = 1
    return end
  ]])
  assert_eval({ ['end'] = 1 }, "{ end = 1 }")
  assert_run(1, [[
    local t = {}
    t.end = 1
    return t.end
  ]])
  assert_run(1, [[
    local t = { end = 1 }
    local key = 'end'
    return t[key]
  ]])
  assert_run(1, [[
    local t = { end = () -> 1 }
    return t.end()
  ]])
  assert_run(1, [[
    local a = { b = { end = () -> 1 } }
    return a.b.end()
  ]])
  assert_run(1, [[
    local a = { x = 1, end = () => self.x }
    return a:end()
  ]])
  assert_run(1, [[
    local a = { b = { x = 1, end = () => self.x } }
    return a.b:end()
  ]])
  assert_run(2, [[
    local a = { end = 1 }
    local b = { end = 2 }
    return (b || a).end
  ]])
  assert_run(1, [[
    local a = { end = 1 }
    local { end } = a
    return end
  ]])
  assert.has_no.error(function()
    compile('print(a.b:end())')
  end)
end)
