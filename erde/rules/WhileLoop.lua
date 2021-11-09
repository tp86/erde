local constants = require('erde.constants')

-- -----------------------------------------------------------------------------
-- WhileLoop
-- -----------------------------------------------------------------------------

local WhileLoop = {}

-- -----------------------------------------------------------------------------
-- Parse
-- -----------------------------------------------------------------------------

function WhileLoop.parse(ctx)
  if not ctx:branchWord('while') then
    ctx:throwExpected('while')
  end

  return {
    rule = 'WhileLoop',
    cond = ctx:Expr(),
    body = ctx:Surround('{', '}', ctx.Block),
  }
end

-- -----------------------------------------------------------------------------
-- Compile
-- -----------------------------------------------------------------------------

function WhileLoop.compile(ctx, node)
  return ('while %s do\n%s\nend'):format(
    ctx:compile(node.cond),
    ctx:compile(node.body)
  )
end

-- -----------------------------------------------------------------------------
-- Return
-- -----------------------------------------------------------------------------

return WhileLoop