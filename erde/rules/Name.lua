local constants = require('erde.constants')

-- -----------------------------------------------------------------------------
-- Name
-- -----------------------------------------------------------------------------

local Name = {}

-- -----------------------------------------------------------------------------
-- Parse
-- -----------------------------------------------------------------------------

function Name.parse(ctx)
  if not constants.ALPHA[ctx.bufValue] then
    error('name must start with alpha')
  end

  local capture = {}
  ctx:consume(1, capture)

  while constants.ALNUM[ctx.bufValue] or ctx.bufValue == '_' do
    ctx:consume(1, capture)
  end

  local value = table.concat(capture)
  for _, keyword in pairs(constants.KEYWORDS) do
    if value == keyword then
      ctx:throwError('name cannot be keyword')
    end
  end

  return { rule = 'Name', value = table.concat(capture) }
end

-- -----------------------------------------------------------------------------
-- Compile
-- -----------------------------------------------------------------------------

function Name.compile(ctx, node)
  return node.value
end

-- -----------------------------------------------------------------------------
-- Return
-- -----------------------------------------------------------------------------

return Name