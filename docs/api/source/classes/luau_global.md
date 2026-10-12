# <code><a href="../../namespaces/sonata">sonata</a>::<a href="../../namespaces/luau">luau</a>::Global</code> (Struct)

One global value stored in an [`Environment`](luau_environment.md) or an
[`EnvNamespace`](luau_environment.md#envnamespace).

`#include <sonata/core/luau/environment.hpp>`

## Definition

```cpp
struct Global {
    using Function = int (*)(VM&);
    using Namespace = std::shared_ptr<EnvNamespace>;
    struct Custom;

    std::variant<Function, std::string, double, bool, Namespace, Custom> value;

    Global(Function function);
    Global(std::string string);
    Global(const char* string);
    Global(double number);
    Global(bool boolean);
    Global(Namespace namespace_);
    Global(Custom custom);
};
```

Every constructor is implicit, so a value converts to a `Global` where one is expected:

```cpp
env.set("answer", 42.0);
env.set("name", "demo");
env.set("tools", std::make_shared<EnvNamespace>());
```

## Kinds

| Alternative | Becomes in Luau |
|---|---|
| `Function` | A function. It receives the [`VM`](luau_vm.md) and works like a `lua_CFunction`: read arguments from `vm.state()`, push results, return how many. |
| `std::string` | A string. |
| `double` | A number. |
| `bool` | A boolean. |
| `Namespace` | A table of the namespace's members. |
| `Custom` | Full userdata with a metatable (see below). |

```cpp
int add(sonata::luau::VM& vm) {
    lua_State* L = vm.state();
    lua_pushnumber(L, luaL_checknumber(L, 1) + luaL_checknumber(L, 2));
    return 1;
}

env.setFunction("add", add);
```

C++ exceptions thrown by a `Function` are caught and turned into Luau errors.

!!! warning "Functions only see the main thread"

    A `Function` receives the `VM`, and `vm.state()` is the VM's **main** thread. When the
    function is called from another Luau thread (a coroutine, or any script run through
    `ModuleLoader::run` / `runtime::runProgram`, where every module and task has its own
    thread), its arguments are on that thread's stack, not on `vm.state()`.

    Use `Function` globals only for code that runs on the main thread (such as
    `VM::execute`). For functions called from programs, register a plain `lua_CFunction`
    instead: in a [built-in library](../writing-a-library.md), or by pushing it yourself with
    `lua_pushcfunction` before sandboxing.

## Custom types

```cpp
struct Global::Custom {
    std::string typeName;
    void (*build)(lua_State* L);
    std::shared_ptr<void> value;
};
```

A C++ value exposed to Luau as full userdata with a metatable.

- **`typeName`** must be a stable, unique string per C++ type. It doubles as the registry name
  that `luaL_newmetatable()`/`luaL_checkudata()` use, so a type's metatable is built at most once
  per `lua_State`, no matter how many globals of that type are loaded.
- **`build`** fills in the metatable. It runs the first time `typeName` is loaded into a state,
  with a fresh, empty table on top of the stack. `__index` is already set to the metatable
  itself, so registering ordinary methods is enough for `obj:method(...)` calls. `build` may
  overwrite `__index` (e.g. with a function, for computed properties). `__gc` and `__type` are
  set automatically **after** `build` runs and always win: don't set them yourself.
- **`value`** is the instance, type-erased. Loading copies this `shared_ptr` into the userdata, so
  the object lives as long as either the `Global` or a Luau reference to it.

### `makeCustomGlobal`

```cpp
template <typename T>
Global makeCustomGlobal(std::string typeName, T value, void (*build)(lua_State* L));
```

Builds a `Global::Custom` holding a fresh copy of `value`.

### `customSelf`

```cpp
template <typename T>
T* customSelf(lua_State* L, int index, const char* typeName);
```

Retrieves the `T` from a custom-type userdata argument at stack `index`. Raises a Luau error
(through `luaL_checkudata`) if the argument isn't userdata of that type. Use it in the methods
registered by `build`, with the same `typeName`.

### Example

```cpp
struct Vector3 { double x, y, z; };

int vectorLength(lua_State* L) {
    Vector3* v = sonata::luau::customSelf<Vector3>(L, 1, "Vector3");
    lua_pushnumber(L, std::sqrt(v->x * v->x + v->y * v->y + v->z * v->z));
    return 1;
}

int vectorX(lua_State* L) {
    lua_pushnumber(L, sonata::luau::customSelf<Vector3>(L, 1, "Vector3")->x);
    return 1;
}

void buildVector3(lua_State* L) {
    // The metatable is on top of the stack; __index already points at it.
    lua_pushcfunction(L, vectorLength, "length");
    lua_setfield(L, -2, "length");
    lua_pushcfunction(L, vectorX, "x");
    lua_setfield(L, -2, "x");
}

env.set("origin", sonata::luau::makeCustomGlobal("Vector3", Vector3{3, 4, 0}, &buildVector3));
// Luau: print(origin:length()) --> 5
```
