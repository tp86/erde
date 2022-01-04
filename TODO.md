# TODO

- formatter (Rule.format)
- improved error messages (add pcalls, Rule.diagnose)
  - pcalls + Rule.diagnose
  - Continue parsing on errors (ignore rest of line, try next line for Statement until succeeds)
- erde REPL

# Long Term TODO

- add real README
- release v0.1.0
- rewrite erde in erde
- Source maps
- remove closure compilations (ternary, null coalescence, optchain, etc).
  - analyze usage and inject code. In particular, transform logical operations into if constructs (ex. `local a = b or c ?? d`)
  - NOTE: cannot simply use functions w/ params (need conditional execution)

# Uncertain Proposals (need community input)

- macros
- decorators
- nested break
- `scope` keyword (allow scoped blocks)
  - ex) `local x = scope { return 4 }`
  - useful for grouping logical computations
- `defer` keyword
  - ex) `defer { return myDefaultExport }`
- optional types