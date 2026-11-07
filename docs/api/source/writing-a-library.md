# Writing a built-in library

A built-in library is a Luau module implemented in C++ and compiled into `sn`. Scripts import it
through the reserved `@sonata` alias, with no files on disk and no manifest entry:

```luau
local hello = require("@sonata/hello")
```

A library is a folder in `source/libs/`. Adding the folder is the whole registration: the build
finds it and generates the registry, so there's no list to update.

## 1. Copy the template

```sh
cd source/libs
cp -r _template hello
mv hello/template.cpp hello/hello.cpp
mv hello/template.luau hello/hello.luau
mv hello/template.test.cpp hello/hello.test.cpp
rm hello/README.md
```

Then rename `template` to `hello` inside the files.

| File | What it is |
|---|---|
| `<name>.cpp` | The library. Must export `NativeLibrary <name>Library()`. |
| `<name>.luau` | Its types. Required, and printed by `sn libs <name> --types`. |
| `<name>.test.cpp` | Its tests, compiled into the test suite. Optional, and any `*.test.cpp` counts. |
| `*.cpp`, subfolders | More sources, picked up automatically. |
| `library.cmake` | Optional: link what the library needs. |

Folders starting with `_` are skipped.

## 2. Write the functions

Each function is a plain `lua_CFunction`, inside `namespace sonata::lib::libs`:

```cpp
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
```

Reading all arguments first matters: `luaL_check*` raises a Lua error, and an argument error then
never skips a destructor.

## 3. Export the definition

```cpp
constexpr NativeFunction kFunctions[] = {
    {"greet", helloGreet},
};

void openHello(lua_State* L) {
    lua_createtable(L, 0, static_cast<int>(std::size(kFunctions)));
    setFunctions(L, kFunctions);
}

} // namespace

NativeLibrary helloLibrary() {
    return {.name = "hello", .open = openHello, .summary = "Greets people"};
}
```

The opener runs once per VM, the first time the library is required, and must push exactly one
value: what `require` returns. The loader makes a table read-only afterwards. Raising a Lua error
from it is fine, but don't let a C++ exception escape.

`summary` is the line `sn libs` shows.

## 4. Document it

Add `docs/docs/api/module/hello.md`, and an entry for it under `nav` in `docs/mkdocs.yml`.

Then reconfigure and run the tests:

```sh
./b.sh test
```

`tests/test_libraries.cpp` checks every library without you writing anything: that it has a
summary and valid types, that it can be required and its table is read-only, and that its
documentation page exists and is linked.

## Native dependencies

Everything a library links has to be vendored and static, because `sn` must run on a machine with
nothing installed. A library that can only be linked dynamically can't be used.

Add the code under `source/external/` as described in its README, then link it from your library:

```cmake
# source/libs/hello/library.cmake
target_link_libraries(sonata_core PRIVATE sonata_hello_dependency)
```

## Reporting through `sn doctor`

A library can report problems only it can notice, such as missing root certificates, by setting
`selfCheck`. It runs on every `sn doctor`, outside any VM, and must not throw:

```cpp
SelfCheckResult checkHello() {
    if (!somethingImportantWorks()) {
        return {false, "this machine has no something"};
    }
    return {true, ""};
}

NativeLibrary helloLibrary() {
    return {.name = "hello", .open = openHello, .summary = "Greets people", .selfCheck = checkHello};
}
```

## Registering a library at runtime

A program embedding Sonata's core can give one VM a native module without changing Sonata, with
[`ModuleLoader::addLibrary`](classes/luau_moduleloader.md):

```cpp
loader.addLibrary({"hello", openHello});
```

## Suspending

Functions that wait for something go through the scheduler, so other tasks keep running. See
[`sonata::sched`](namespaces/sched.md).
