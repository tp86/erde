local _ = require('erde.rules.helpers')
local state = require('erde.state')
local supertable = require('erde.supertable')

return {
  Newline = {
    pattern = _.P('\n') * (_.Cp() / function(position)
      state.currentLine = state.currentLine + 1
      state.currentLineStart = position
    end),
  },
  Space = {
    pattern = (_.V('Newline') + _.space) ^ 0,
  },
  Comment = {
    pattern = _.Pad(_.Sum({
      _.Pad('---') * (_.P(1) - _.P('---')) ^ 0 * _.Pad('---'),
      _.Pad('--') * (_.P(1) - _.V('Newline')) ^ 0,
    })) / '',
  },
  Name = {
    pattern = function()
      local bodychar = _.alnum + _.P('_')
      local keyword = _.Sum({
        'local',
        'global',
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
      }) * #-bodychar
      return (_.alpha + _.P('_')) * bodychar ^ 0 - keyword
    end,
  },
  IndexChain = {
    pattern = function()
      local ArgList = _.Parens(_.List(_.CsV('Expr')))
      return (
        _.Product({
          _.Pad('?') * _.Cc(true) + _.Cc(false),
          _.Sum({
            _.Cc(1) * _.Pad('.') * _.CsV('Name'),
            _.Cc(2) * _.Pad('[') * _.CsV('Expr') * _.Pad(']'),
            _.Cc(3) * ArgList,
            _.Cc(4) * _.Pad(':') * _.CsV('Name'),
          }),
        }) / _.map('opt', 'variant', 'value')
      ) ^ 0 / _.pack
    end
  },
  Id = {
    pattern = _.Product({
      _.Sum({
        _.Cc(1) * _.CsV('Name'),
        _.Cc(2) * _.Parens(_.CsV('Expr')),
      }),
      _.V('IndexChain'),
    }),
    compiler = function(variant, base, chain)
      return variant == 1
        and { base = base, chain = chain }
        or { base = '('..base..')', chain = chain }
    end,
  },
  IdExpr = {
    pattern = _.V('Id'),
    compiler = _.indexChain(
      function(id) return id end,
      function(id) return 'return '..id end
    ),
  },
  Return = {
    pattern = _.Pad('return') * _.V('ExprList'),
    compiler = function(exprList)
      return 'return '..exprList:join(',')
    end,
  },
}