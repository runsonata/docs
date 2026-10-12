# <code><a href="../../namespaces/sonata">sonata</a>::<a href="../../namespaces/luau">luau</a>::ModuleLoader</code> (Class)

Implements `require` for one VM, and runs a program's entry script.

`#include <sonata/core/module.hpp>`

```cpp
using namespace sonata::luau;

ModuleLoader loader(std::make_unique<FileSystemSource>()); // declare before the VM
VM vm;

loader.addAlias("utils", "/home/me/project/.sonata/deps/utils");
loader.install(vm);
luaL_sandbox(vm.state());
loader.run(vm, "/home/me/project/main.luau");
```

## Module paths

Every module is identified by a **module path**: an absolute path with forward slashes.

```
/home/me/project/src/util.luau
C:/project/src/util.luau
```

`sn run` uses the real absolute paths on disk. `sn build` uses the same tree under a virtual
root: `/main.luau`, `/src/util.luau`, `/.sonata/deps/foo/init.luau`, ...
[`normalizePath`](../namespaces/luau.md#normalizepath) produces them.

## Require rules

| Request | Resolves |
|---|---|
| `require("./helper")`, `require("../shared/util")` | Relative to the requiring file's folder. |
| `require("@name")`, `require("@name/path")` | Through an alias (see below). |
| `require("@sonata/name")` | A [built-in library](../namespaces/lib.md). |

A path `P` resolves to `P.luau`, or `P/init.luau` if that doesn't exist; if both exist, the
require is an error. If `P` is a package root whose manifest names an `entrypoint`, that file
takes `init.luau`'s place. Anything not starting with `./`, `../` or `@` is rejected, keeping
bare names free for a future package mechanism.

### Where `@name` points

1. **Aliases registered with `addAlias()`.** These always win.
2. **The dependencies declared in the manifest of the package that contains the requiring
   file**: the nearest folder above it with a `.sonata/project.luau`. The dependency is looked
   up in the flat deps folder: next to the package if the package itself sits in a
   `.sonata/deps` folder, otherwise in its own `.sonata/deps`.

(2) lets a dependency require the packages its own manifest lists without anyone registering
aliases for them. Which manifest applies depends on the file doing the require. Packages aren't
isolated from each other: a registered name is visible everywhere, and since everything is
installed flat, a name always means the same folder. How manifests are read is up to the
[`ModuleSource`](luau_modulesource.md).

### Modules

A module runs **once per VM**, on its own sandboxed thread, and must return exactly one non-nil
value. That value is cached and returned by every later require of the same file. Cyclic
requires are reported as errors, with the chain.

## Lifetime

!!! warning

    `install()` gives the VM a raw pointer to the loader, so the loader must **outlive every
    piece of Lua code that can run**, and must not be moved. Use one loader per VM, and declare
    it before the VM.

`ModuleLoader` can't be copied.

## Methods

### Constructor

```cpp
explicit ModuleLoader(std::unique_ptr<ModuleSource> source);
```

Takes ownership of the [source](luau_modulesource.md) modules are read from, and registers every
[built-in library](../namespaces/lib.md#registerbuiltinlibraries) compiled into the binary.

### `addAlias`

```cpp
void addAlias(std::string name, std::string_view directory);
```

Registers `@name` as an alias for a directory (a module path). Throws `std::invalid_argument` if
the name or path is invalid. An alias registered here takes priority over the same name in a
manifest. [`PackageManager::registerAliases`](package_manager.md#registeraliases) calls this for
every installed package.

### `install`

```cpp
void install(VM& vm);
```

Defines the global `require` on the VM. Call it **before** `luaL_sandbox()` (or whatever makes
your globals read-only).

### `run`

```cpp
void run(VM& vm, std::string_view entry);
```

Runs `entry` (a module path) as the program's entry point. The entry goes through the same
machinery as required modules, so its chunk name is its path and relative requires work from
it. It may return anything.

The entry runs as the first task of the VM's [scheduler](sched_scheduler.md), and `run()` keeps
the scheduler going until nothing is left to do: tasks the entry started outlive it. Errors in
those tasks are reported, not thrown; an error in the entry itself stops everything.

Throws [`ModuleError`](#moduleerror), including a stack trace, if the entry can't be found or
compiled, or fails.

### `addLibrary`

```cpp
void addLibrary(lib::NativeLibrary library);
```

Registers an extra built-in: `require("@sonata/<name>")`. Throws `std::invalid_argument` if the
name is invalid or taken. See
[Registering a library at runtime](../writing-a-library.md#registering-a-library-at-runtime).

### `restrictLibraries`

```cpp
void restrictLibraries(const std::vector<std::string>& allowed, std::string hint = {});
```

Only lets scripts require the built-in libraries named in `allowed`. Requiring any other one
fails with an error that ends in `hint` (e.g. where to add the library). This enforces
`build.libraries`, so `sn run` refuses exactly what a built program wouldn't have.

Names that aren't registered are ignored. Without a call to this, every registered library is
available.

## `ModuleError`

```cpp
class ModuleError : public std::runtime_error;
```

Raised for failures the module system detects itself: a module that can't be read or compiled,
or an entry script that errors inside `run()`. For an error raised by the script, `what()` is
the message followed by `"\nstacktrace:\n"` and the trace.
