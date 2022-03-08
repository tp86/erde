-- -----------------------------------------------------------------------------
-- Parse
-- -----------------------------------------------------------------------------

describe('TryCatch.parse', function()
  spec('try catch', function()
    assert.subtable({
      try = { ruleName = 'Block' },
      catch = { ruleName = 'Block' },
    }, parse.TryCatch(
      'try {} catch() {}'
    ))
    assert.subtable({
      try = { ruleName = 'Block' },
      errorName = 'err',
      catch = { ruleName = 'Block' },
    }, parse.TryCatch(
      'try {} catch(err) {}'
    ))
  end)
end)

-- -----------------------------------------------------------------------------
-- Compile
-- -----------------------------------------------------------------------------

describe('TryCatch.compile', function()
  spec('try catch', function()
    assert.run(
      1,
      compile.Block([[
        try {
          error('some error')
        } catch() {
          return 1
        }
        return 2
      ]])
    )
    assert.run(
      2,
      compile.Block([[
        try {
          -- no error
        } catch() {
          return 1
        }
        return 2
      ]])
    )
  end)
end)