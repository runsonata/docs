# <code><a href="../sonata">sonata</a>::lib</code> (namespace)

Built-in libraries: Luau modules implemented in C++ and served by
[`ModuleLoader`](../classes/luau_moduleloader.md) under the reserved `@sonata` alias.

`#include <sonata/core/library.hpp>`

See [Writing a built-in library](../writing-a-library.md) for a walkthrough.

## Classes & Structs

| Class | Description |
|---|---|
| [`LibraryRegistry`](../classes/lib_registry.md) | The set of libraries a `ModuleLoader` can serve. |
| [`NativeFunction`](#nativefunction) | A C function exposed to Luau. |
| [`NativeLibrary`](#nativelibrary) | A library: a name and an opener. |

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
    std::string name;          // "path" makes it available as require("@sonata/path")
    NativeOpener open = nullptr;
};
```

`name` may contain lowercase letters, digits, `_` and `-` only.

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

### `registerBuiltinLibraries`

```cpp
void registerBuiltinLibraries(LibraryRegistry& registry);
```

Adds every library compiled into this binary. `ModuleLoader` calls it itself. Which libraries
that is depends on the `SONATA_LIBS` CMake option: a runtime built by `sn build` may contain only
a few.

### `knownLibraryNames`

```cpp
const std::vector<std::string>& knownLibraryNames();
```

The names of every library Sonata knows about (`SONATA_ALL_LIBS`), sorted, whether or not this
binary has them compiled in. Used to validate `build.libraries`, and to tell "not enabled for
this program" apart from "unknown".

## The built-in libraries

| Name | Opener | Source |
|---|---|---|
| `compress` | `openCompress` | `src/core/libs/compress.cpp` |
| `crypto` | `openCrypto` | `src/core/libs/crypto.cpp` |
| `datetime` | `openDatetime` | `src/core/libs/datetime.cpp` |
| `fs` | `openFs` | `src/core/libs/fs.cpp`, `fs/` |
| `image` | `openImage` | `src/core/libs/image.cpp` |
| `json` | `openJson` | `src/core/libs/json.cpp` |
| `luau` | `openLuau` | `src/core/libs/luau.cpp` |
| `net` | `openNet` | `src/core/libs/net.cpp`, `net/` |
| `path` | `openPath` | `src/core/libs/path.cpp` |
| `pocket` | `openPocket` | `src/core/libs/pocket.cpp` |
| `process` | `openProcess` | `src/core/libs/process.cpp` |
| `regex` | `openRegex` | `src/core/libs/regex.cpp` |
| `serde` | `openSerde` | `src/core/libs/serde.cpp`, `serde_formats.hpp` |
| `sonata` | `openSonata` | `src/core/libs/sonata.cpp` |
| `sys` | `openSys` | `src/core/libs/sys.cpp` |
| `task` | `openTask` | `src/core/libs/task.cpp` |
| `term` | `openTerm` | `src/core/libs/term.cpp` |

The openers are declared in `src/core/libs/libs.hpp`, in the private `sonata::lib::libs`
namespace. The outside world only reaches them through `LibraryRegistry` and
`require("@sonata/<name>")`.
