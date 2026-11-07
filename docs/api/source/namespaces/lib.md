# <code><a href="../sonata">sonata</a>::lib</code> (namespace)

Built-in libraries: Luau modules implemented in C++ and served by
[`ModuleLoader`](../classes/luau_moduleloader.md) under the reserved `@sonata` alias.

`#include <sonata/runtime/library.hpp>`

See [Writing a built-in library](../writing-a-library.md) for a walkthrough.

## Classes & Structs

| Class | Description |
|---|---|
| [`LibraryRegistry`](../classes/lib_registry.md) | The set of libraries a `ModuleLoader` can serve. |
| [`NativeFunction`](#nativefunction) | A C function exposed to Luau. |
| [`NativeLibrary`](#nativelibrary) | A library: its name, opener, summary, types and self-check. |
| [`SelfCheckResult`](#selfcheckresult) | What `sn doctor` learned from a library's self-check. |

### `NativeFunction`

```cpp
struct NativeFunction {
    const char* name;
    int (*function)(lua_State* L);
    int (*continuation)(lua_State* L, int status) = nullptr;
};
```

A function exposed to Luau. `name` is both its key in the library table and the name shown in
error messages and stack traces.

`continuation` is only needed by functions that suspend the calling thread through the
[scheduler](../classes/sched_scheduler.md) and want to run again when it resumes. It is the
`lua_Continuation` Luau calls instead of returning straight to the script.

### `NativeOpener`

```cpp
using NativeOpener = void (*)(lua_State* L);
```

Called the first time a script requires the library. It must push **exactly one value**, which
becomes the value of `require(...)`. The loader caches it, so the opener runs once per VM. If the
value is a table, the loader marks it read-only (nested tables are up to the opener).

Raising a Luau error (`luaL_error`) from an opener is fine: the require fails with that message.
Don't let C++ exceptions escape it.

### `NativeLibrary`

```cpp
struct NativeLibrary {
    std::string name;            // "path" makes it available as require("@sonata/path")
    NativeOpener open = nullptr;
    std::string summary;         // one line, for `sn libs`
    SelfCheck selfCheck = nullptr;
    std::string_view types;      // the contents of <name>.luau, filled in by the generated registry
};
```

`name` may contain lowercase letters, digits and `_` only, and starts with a letter.

### `SelfCheckResult`

```cpp
struct SelfCheckResult {
    bool ok = true;
    std::string detail;  // shown either way; say what's wrong, or what was found
    bool serious = true; // if not ok: an error, or only a warning
};

using SelfCheck = SelfCheckResult (*)();
```

Optional. Lets a library report problems only it can notice, such as missing root certificates.
It runs outside any VM and must not throw. See
[Reporting through `sn doctor`](../writing-a-library.md#reporting-through-sn-doctor).

## Functions

### `setFunctions`

```cpp
void setFunctions(lua_State* L, const NativeFunction* functions, std::size_t count);

template <std::size_t N>
void setFunctions(lua_State* L, const NativeFunction (&functions)[N]);
```

Sets every function in `functions` as a field of the table on top of the stack.

```cpp
constexpr NativeFunction kFunctions[] = {
    {"greet", helloGreet},
    {"wait", helloWait, helloWaitK},
};

void openHello(lua_State* L) {
    lua_createtable(L, 0, std::size(kFunctions));
    setFunctions(L, kFunctions);
}
```

### `builtinLibraries`

```cpp
const std::vector<NativeLibrary>& builtinLibraries();
```

Every built-in library, sorted by name. Generated from the folders in `source/libs/` (see
`cmake/builtin_registry.cpp.in`).

### `registerBuiltinLibraries`

```cpp
void registerBuiltinLibraries(LibraryRegistry& registry);
```

Adds every built-in library. `ModuleLoader` calls it itself. Every `sn` has all of them.

### `knownLibraryNames`

```cpp
const std::vector<std::string>& knownLibraryNames();
```

The names of every built-in library, sorted. Used to validate `build.libraries`, and to tell "not
enabled for this program" apart from "unknown".

## The built-in libraries

The list is generated from the folders in `source/libs/`, and `sn libs` prints it. Each library
exports `NativeLibrary <name>Library()` in the private `sonata::lib::libs` namespace. The outside
world only reaches them through `LibraryRegistry` and `require("@sonata/<name>")`.
