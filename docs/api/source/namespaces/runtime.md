# <code><a href="../sonata">sonata</a>::runtime</code> (namespace)

Runs a program. `sn run` and executables made by `sn build` both go through here, so they behave
the same.

`#include <sonata/core/runtime.hpp>`

## `ProgramInfo`

```cpp
struct ProgramInfo {
    std::string name;       // from the manifest
    std::string version;    // from the manifest
    std::string root;       // the project folder (sn run) or the executable's folder (built)
    std::string entry;      // module path of the entry script
    bool bundled = false;   // true inside a program made by "sn build"
    std::string executable; // path of the program's executable (bundled only)
};
```

What a running program knows about itself. It becomes the [`sonata` global](../../module/globals.md#sonata):

| Global field | From |
|---|---|
| `sonata.version` | Sonata's version ([`info::version_string()`](info.md)). |
| `sonata.platform` | [`info::platform_string()`](info.md). |
| `sonata.entry` | `entry` |
| `sonata.bundled` | `bundled` |
| `sonata.executable` | `executable` (only set when bundled) |
| `sonata.project.name` | `name` |
| `sonata.project.version` | `version` |
| `sonata.project.root` | `root` |

## `runProgram`

```cpp
void runProgram(luau::ModuleLoader& loader, const ProgramInfo& info,
                const std::vector<std::string>& args, const Pocket* pocket);
```

1. Creates the [`VM`](../classes/luau_vm.md), with the `sonata` and `args` globals. `args` (the
   strings given to the program) is a read-only array, also exposed as `process.args`.
2. Installs `require()` from `loader`, which must already have its aliases and library
   restrictions, and makes `pocket` available to `@sonata/pocket` (it may be `nullptr`, in which
   case every pocket function raises).
3. Sandboxes the globals (`luaL_sandbox`) and runs the entry through
   [`ModuleLoader::run`](../classes/luau_moduleloader.md#run), which keeps the scheduler going
   until nothing is left to do.

`loader` and `pocket` must outlive the call. Throws [`luau::ModuleError`](../classes/luau_moduleloader.md#moduleerror),
with a stack trace, if the script fails.

### How `sn run` uses it

1. `Project::find()` locates the project and its entrypoint.
2. A `PackageManager` checks (or with `--install`, installs) the dependencies and registers an
   `@name` alias for each.
3. `selectLibraries()` works out the allowed built-in libraries; the loader is restricted to them.
4. A `DiskPocket` is filled with every package's `build.assets`.
5. `runProgram()` runs the entrypoint with a `FileSystemSource`.

### How a built program uses it

`runtime/main.cpp` (`snrt`) reads the [bundle](bundle.md) at the end of its own executable, fills
a `MemorySource` with the compiled modules and packages, a `MemoryPocket` with the assets, and
registers the aliases and library restriction the bundle carries. Then it calls `runProgram()`
with `bundled = true`.
