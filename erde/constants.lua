local C = {}

C.VERSION = '0.3-2'

-- Get the current platform path separator. Note that while this is undocumented
-- in the Lua 5.1 manual, it is indeed supported in 5.1+.
--
-- https://www.lua.org/manual/5.3/manual.html#pdf-package.config
C.PATH_SEPARATOR = package.config:sub(1, 1)

-- A header comment we inject into compiled code in order to track which files
-- have been generated by the cli (and thus allows us to also clean them later).
C.COMPILED_FOOTER_COMMENT = '-- __ERDE_COMPILED__'
C.COMPILED_FOOTER_COMMENT_LEN = #C.COMPILED_FOOTER_COMMENT

-- Flag to know whether or not we are running under the cli. Required for more
-- precise error rewriting.
C.IS_CLI_RUNTIME = false

-- Flag to display more erde internals during error rewriting.
C.DEBUG = false

-- -----------------------------------------------------------------------------
-- Lua Target
-- -----------------------------------------------------------------------------

C.LUA_TARGET = '5.1+'

C.VALID_LUA_TARGETS = {
  'jit',
  '5.1',
  '5.1+',
  '5.2',
  '5.2+',
  '5.3',
  '5.3+',
  '5.4',
  '5.4+',
}

for i, target in ipairs(C.VALID_LUA_TARGETS) do
  C.VALID_LUA_TARGETS[target] = true
end

-- -----------------------------------------------------------------------------
-- Keywords / Terminals
-- -----------------------------------------------------------------------------

C.KEYWORDS = {
  'local',
  'global',
  'module',
  'if',
  'elseif',
  'else',
  'for',
  'in',
  'while',
  'repeat',
  'until',
  'do',
  'function',
  'false',
  'true',
  'nil',
  'return',
  'try',
  'catch',
  'break',
  'continue',
}

-- Words that are keywords in Lua but NOT in Erde. These are allowed to be used
-- as variable names in Erde, but must be transformed when compiling.
C.LUA_KEYWORDS = {
  ['not'] = true,
  ['and'] = true,
  ['or'] = true,
  ['end'] = true,
  ['then'] = true,
}

C.TERMINALS = {
  'true',
  'false',
  'nil',
  '...',
}

-- -----------------------------------------------------------------------------
-- Operations
-- -----------------------------------------------------------------------------

C.LEFT_ASSOCIATIVE = -1
C.RIGHT_ASSOCIATIVE = 1

C.UNOPS = {
  ['-'] = { prec = 13 },
  ['#'] = { prec = 13 },
  ['!'] = { prec = 13 },
  ['~'] = { prec = 13 },
}

for opToken, op in pairs(C.UNOPS) do
  op.token = opToken
end

C.BITOPS = {
  ['|'] = { prec = 6, assoc = C.LEFT_ASSOCIATIVE },
  ['~'] = { prec = 7, assoc = C.LEFT_ASSOCIATIVE },
  ['&'] = { prec = 8, assoc = C.LEFT_ASSOCIATIVE },
  ['<<'] = { prec = 9, assoc = C.LEFT_ASSOCIATIVE },
  ['>>'] = { prec = 9, assoc = C.LEFT_ASSOCIATIVE },
}

-- Compiling bit operations for these targets are dangerous, since Mike Pall's
-- LuaBitOp only works on 5.1 + 5.2, bit32 only works on 5.2, and 5.3 + 5.4 have
-- built-in bit operator support.
C.INVALID_BITOP_LUA_TARGETS = {
  ['5.1+'] = true,
  ['5.2+'] = true,
}

-- User specified library to use for bit operations.
C.BITLIB = nil

C.BITLIB_METHODS = {
  ['|'] = 'bor',
  ['~'] = 'bxor',
  ['&'] = 'band',
  ['<<'] = 'lshift',
  ['>>'] = 'rshift',
}

C.BINOPS = {
  ['||'] = { prec = 3, assoc = C.LEFT_ASSOCIATIVE },
  ['&&'] = { prec = 4, assoc = C.LEFT_ASSOCIATIVE },
  ['=='] = { prec = 5, assoc = C.LEFT_ASSOCIATIVE },
  ['!='] = { prec = 5, assoc = C.LEFT_ASSOCIATIVE },
  ['<='] = { prec = 5, assoc = C.LEFT_ASSOCIATIVE },
  ['>='] = { prec = 5, assoc = C.LEFT_ASSOCIATIVE },
  ['<'] = { prec = 5, assoc = C.LEFT_ASSOCIATIVE },
  ['>'] = { prec = 5, assoc = C.LEFT_ASSOCIATIVE },
  ['..'] = { prec = 10, assoc = C.LEFT_ASSOCIATIVE },
  ['+'] = { prec = 11, assoc = C.LEFT_ASSOCIATIVE },
  ['-'] = { prec = 11, assoc = C.LEFT_ASSOCIATIVE },
  ['*'] = { prec = 12, assoc = C.LEFT_ASSOCIATIVE },
  ['/'] = { prec = 12, assoc = C.LEFT_ASSOCIATIVE },
  ['//'] = { prec = 12, assoc = C.LEFT_ASSOCIATIVE },
  ['%'] = { prec = 12, assoc = C.LEFT_ASSOCIATIVE },
  ['^'] = { prec = 14, assoc = C.RIGHT_ASSOCIATIVE },
}

for opToken, op in pairs(C.BITOPS) do
  C.BINOPS[opToken] = op
end

for opToken, op in pairs(C.BINOPS) do
  op.token = opToken
end

C.BINOP_ASSIGNMENT_TOKENS = {
  ['||'] = true,
  ['&&'] = true,
  ['..'] = true,
  ['+'] = true,
  ['-'] = true,
  ['*'] = true,
  ['/'] = true,
  ['//'] = true,
  ['%'] = true,
  ['^'] = true,
  ['|'] = true,
  ['~'] = true,
  ['&'] = true,
  ['<<'] = true,
  ['>>'] = true,
}

-- -----------------------------------------------------------------------------
-- Lookup Tables
-- -----------------------------------------------------------------------------

C.SURROUND_ENDS = {
  ['('] = ')',
  ['['] = ']',
  ['{'] = '}',
}

C.SYMBOLS = {
  ['->'] = true,
  ['=>'] = true,
  ['...'] = true,
  ['::'] = true,
}

for opToken, op in pairs(C.BINOPS) do
  if #opToken > 1 then
    C.SYMBOLS[opToken] = true
  end
end

-- Valid escape characters for 5.1+
C.STANDARD_ESCAPE_CHARS = {
  a = true,
  b = true,
  f = true,
  n = true,
  r = true,
  t = true,
  v = true,
  ['\\'] = true,
  ['"'] = true,
  ["'"] = true,
  ['\n'] = true,
}

C.ALPHA = {}
C.DIGIT = {}
C.HEX = {}
C.WORD_HEAD = { ['_'] = true }
C.WORD_BODY = { ['_'] = true }

for byte = string.byte('0'), string.byte('9') do
  local char = string.char(byte)
  C.DIGIT[char] = true
  C.HEX[char] = true
  C.WORD_BODY[char] = true
end

for byte = string.byte('A'), string.byte('F') do
  local char = string.char(byte)
  C.ALPHA[char] = true
  C.HEX[char] = true
  C.WORD_HEAD[char] = true
  C.WORD_BODY[char] = true
end

for byte = string.byte('G'), string.byte('Z') do
  local char = string.char(byte)
  C.ALPHA[char] = true
  C.WORD_HEAD[char] = true
  C.WORD_BODY[char] = true
end

for byte = string.byte('a'), string.byte('f') do
  local char = string.char(byte)
  C.ALPHA[char] = true
  C.HEX[char] = true
  C.WORD_HEAD[char] = true
  C.WORD_BODY[char] = true
end

for byte = string.byte('g'), string.byte('z') do
  local char = string.char(byte)
  C.ALPHA[char] = true
  C.WORD_HEAD[char] = true
  C.WORD_BODY[char] = true
end

-- -----------------------------------------------------------------------------
-- Return
-- -----------------------------------------------------------------------------

return C
