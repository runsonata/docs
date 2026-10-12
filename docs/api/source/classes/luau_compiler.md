# <code><a href="../../namespaces/sonata">sonata</a>::<a href="../../namespaces/luau">luau</a>::Compiler</code> (Class)

Turns Luau source into [`Bytecode`](luau_bytecode.md).

`#include <sonata/core/luau/compiler.hpp>`

## Definition

```cpp
class Compiler {
public:
    struct Options {
        int optimizationLevel = 1; // 0..2; 2 inlines functions, unrolls loops
        int debugLevel = 1;        // 0..2; 1 = line info for stack traces
    };

    Compiler() = default;
    explicit Compiler(Options options);

    Bytecode compile(std::string_view source) const;
};
```

## `Options`

The defaults are Luau's own, and therefore what `sn run` uses. `sn build` sets them from
`build.optimize` / `build.debug` or `-O` / `-g`.

| Field | Values |
|---|---|
| `optimizationLevel` | `0` none, `1` default, `2` aggressive (inlining, loop unrolling). |
| `debugLevel` | `0` none, `1` line info for stack traces, `2` full debug info. |

## Methods

### `compile`

```cpp
Bytecode compile(std::string_view source) const;
```

Compiles `source`. It never throws for bad source: a syntax error produces bytecode whose
[`compileError()`](luau_bytecode.md#compileerror) returns the message.

```cpp
sonata::luau::Compiler compiler({.optimizationLevel = 2, .debugLevel = 0});
sonata::luau::Bytecode code = compiler.compile("return 1 + 1");
```
