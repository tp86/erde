-- -----------------------------------------------------------------------------
-- Parse
-- -----------------------------------------------------------------------------

describe('WhileLoop.parse', function()
  spec('rule', function()
    assert.are.equal('WhileLoop', parse.WhileLoop('while true {}').rule)
  end)

  spec('while loop', function()
    assert.has_subtable({
      rule = 'WhileLoop',
      cond = { value = 'true' },
      body = {},
    }, parse.WhileLoop(
      'while true {}'
    ))
  end)
end)

-- -----------------------------------------------------------------------------
-- Compile
-- -----------------------------------------------------------------------------

describe('WhileLoop.compile', function()
  spec('while loop', function()
    assert.run(
      10,
      compile.Block([[
        local x = 0
        while x < 10 {
          x += 2
        }
        return x
      ]])
    )
  end)
end)