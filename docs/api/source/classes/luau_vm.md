# <code><a href="../../namespaces/sonata">sonata</a>::<a href="../../namespaces/luau">luau</a>::VM</code> (Class)

Owns a Luau state (`lua_State`) with the standard libraries opened.

`#include <sonata/core/luau/vm.hpp>`

## Definition

```cpp
class VM {
public:
    VM();
    ~VM();

    VM(const VM&) = delete;
    VM& operator=(const VM&) = delete;

    lua_State* state();
    int execute(const Bytecode& bytecode);
};
```

## Lifetime

The constructor creates the state with `luaL_newstate()` and opens the standard Luau libraries
(`luaL_openlibs`). The destructor calls `lua_close()`, which also destroys the VM's
[scheduler](sched_scheduler.md) if it has one. A `VM` can't be copied.

Objects whose address the VM keeps (a [`ModuleLoader`](luau_moduleloader.md), a
[`Pocket`](pocket.md)) must be declared **before** the VM, so they are destroyed after it.

## Methods

### `state`

```cpp
lua_State* state();
```

The raw state, for Luau's C API.

### `execute`

```cpp
int execute(const Bytecode& bytecode);
```

Loads `bytecode` (as chunk `"=execute"`) and calls it with `lua_pcall`. Returns `LUA_OK`, or the
error status from loading or running. On error, the error value is popped and discarded; results
of a successful run are left on the stack.

`execute` is a quick way to run a chunk. It doesn't install `require`, run the scheduler, or
report error messages. For programs, use [`ModuleLoader::run`](luau_moduleloader.md#run) or
[`runtime::runProgram`](../namespaces/runtime.md#runprogram).

```cpp
sonata::luau::VM vm;
sonata::luau::Compiler compiler;

if (vm.execute(compiler.compile("x = 40 + 2")) == LUA_OK) {
    lua_getglobal(vm.state(), "x");
    std::cout << lua_tonumber(vm.state(), -1) << '\n'; // 42
}
```
