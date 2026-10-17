# Writing a built-in library

A built-in library is a Luau module implemented in C++ and compiled into Sonata. Scripts import
it through the reserved `@sonata` alias, with no files on disk and no manifest entry:

```luau
local hello = require("@sonata/hello")
```

This page adds a library to Sonata itself. To give *your own* embedding program a native module
without changing Sonata, see [Registering a library at runtime](#registering-a-library-at-runtime).

`src/core/libs/example.cpp` is a complete, commented template, and `src/core/libs/path.cpp` is a
full real library.

## 1. Write the functions

Each function is a plain `lua_CFunction`. Put the library in `src/core/libs/<name>.cpp`, inside
`namespace sonata::lib::libs`:

```cpp
// @sonata/hello: a tiny example library.
//
//     local hello = require("@sonata/hello")
//
//     hello.greet("Ada")          --> "Hello, Ada!"
//     hello.greet("Ada", "Hi")    --> "Hi, Ada!"

#include <string>

#include <sonata/core/library.hpp>
#include "lua.h"
#include "lualib.h"

#include "libs.hpp"

namespace sonata::lib::libs {

namespace {

// hello.greet(name: string, greeting: string?): string
int helloGreet(lua_State* L) {
    // Validate every argument first...
    const char* name = luaL_checkstring(L, 1);
    const char* greeting = luaL_optstring(L, 2, "Hello");

    // ...and only then create C++ objects.
    const std::string text = std::string(greeting) + ", " + name + "!";
    lua_pushlstring(L, text.data(), text.size());
    return 1;
}

constexpr NativeFunction kFunctions[] = {
    {"greet", helloGreet},
};

} // namespace

void openHello(lua_State* L) {
    lua_createtable(L, 0, static_cast<int>(std::size(kFunctions)));
    setFunctions(L, kFunctions);
}

} // namespace sonata::lib::libs
```

## 2. Write the opener

The opener, `open<Name>`, is called the first time a script requires the library. It must push
**exactly one value**, normally a table, which becomes the result of `require`. The loader
caches it (the opener runs once per VM) and makes a returned table read-only. Nested tables are
up to you; `lua_setreadonly(L, idx, 1)` makes them read-only too.

The name is derived from the library name with its first letter capitalized: `hello` →
`openHello`, `datetime` → `openDatetime`.

## 3. Declare it and add it to the build

Declare the opener in `src/core/libs/libs.hpp`:

```cpp
void openHello(lua_State* L);    // @sonata/hello
```

Add the name to `SONATA_ALL_LIBS` in `src/CMakeLists.txt`:

```cmake
set(SONATA_ALL_LIBS
  fs path sys task process term net json crypto datetime compress regex serde sonata pocket luau image hello)
```

That's all the registration there is. CMake generates `builtin_registry.cpp` from that list,
which makes the library available to `require`, to
[`registerBuiltinLibraries`](namespaces/lib.md#registerbuiltinlibraries), and to the validation
of [`build.libraries`](../../guide/manifest.md#buildlibraries). Library names may use lowercase
letters, digits, `_` and `-`.

A library too big for one file may put more sources in `src/core/libs/<name>/`; every `.cpp`
there is compiled along with it (see `net/`).

## Rules for bindings

**Validate all arguments before creating C++ objects.** `luaL_check*`, `luaL_argcheck` and
`luaL_error` raise a Luau error, which may `longjmp` past your C++ destructors depending on how
Luau was built. If nothing with a destructor is alive yet, nothing leaks.

**Report late failures without raising from inside C++ scopes.** If an error can only be
detected while C++ objects exist, push the message, let the objects go out of scope, and raise
afterwards. `fs.cpp` and `path.cpp` use a small `finish()` helper for this.

**Never let a C++ exception escape** a `lua_CFunction` or an opener. Catch it and turn it into a
Luau error (or a `nil, message` return).

**Pick one error convention** and document it: raise for misuse and failures (like `fs`), or
return `nil, message` for failures that depend on the outside world (like `net`).

**Document the API at the top of the file**, in the same style as the other libraries. The
[module reference](../module/index.md) is written from those comments.

## Waiting without blocking

A function that would block (I/O, a slow computation) should let other tasks run. The
[scheduler](classes/sched_scheduler.md) offers several ways to suspend the calling task; the
simplest is `await`, which runs a job on a worker thread:

```cpp
#include <chrono>
#include <thread>

#include <sonata/core/scheduler.hpp>

// hello.slowGreet(name: string): string
int helloSlowGreet(lua_State* L) {
    const std::string name = luaL_checkstring(L, 1);

    return sched::Scheduler::of(L).await(L, [name]() -> sched::Completion {
        // Runs on a worker thread: never touch Lua here.
        std::this_thread::sleep_for(std::chrono::seconds(1));
        std::string text = "Hello, " + name + "!";

        // Runs on the VM's thread afterwards and pushes the results.
        return [text](lua_State* T) {
            lua_pushlstring(T, text.data(), text.size());
            return 1;
        };
    });
}
```

The job must not touch Lua in any way. The completion it returns runs on the VM's thread and
pushes the results (or one error value, returning `sched::kRaise`). Exceptions thrown by the job
become Luau errors.

Functions that need to run again after resuming (to retry an operation, for instance) register a
**continuation** in their `NativeFunction` entry and use `waitIo`, `park` or `await` with it:

```cpp
constexpr NativeFunction kFunctions[] = {
    {"recv", sockRecv, sockRecvK}, // sockRecvK is a lua_Continuation
};
```

See [`Scheduler`](classes/sched_scheduler.md) for the details, and `task.cpp` and
`net/socket.cpp` for real examples.

## Tests

Library tests live in `tests/test_builtins.cpp` and use doctest. Run them with
`./b.sh test`.

## Registering a library at runtime

A program that embeds Sonata can add native modules without touching Sonata's build, with
[`ModuleLoader::addLibrary`](classes/luau_moduleloader.md#addlibrary):

```cpp
int appVersion(lua_State* L) {
    lua_pushstring(L, "2.3.1");
    return 1;
}

void openApp(lua_State* L) {
    static const sonata::lib::NativeFunction functions[] = {
        {"version", appVersion},
    };
    lua_createtable(L, 0, 1);
    sonata::lib::setFunctions(L, functions);
}

// ...
sonata::luau::ModuleLoader loader(std::make_unique<sonata::luau::FileSystemSource>());
loader.addLibrary({"app", openApp});
```

Scripts then `require("@sonata/app")`. The name must not clash with a built-in library, or
`addLibrary` throws `std::invalid_argument`.
