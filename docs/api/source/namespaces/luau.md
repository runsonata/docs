# <code><a href="../sonata">sonata</a>::luau</code> (namespace)

Everything Luau-related:

- creating and running a Luau VM;
- compiling Luau source to bytecode;
- reading and writing static Luau tables ("data files" such as `project.luau`);
- defining globals for a VM;
- the module system behind `require`.

## Classes & Structs

| Class | Header | Description |
|---|---|---|
| [`VM`](../classes/luau_vm.md) | `luau/vm.hpp` | Owns a `lua_State`. |
| [`Compiler`](../classes/luau_compiler.md) | `luau/compiler.hpp` | Turns Luau source into [`Bytecode`](../classes/luau_bytecode.md). |
| [`Bytecode`](../classes/luau_bytecode.md) | `luau/compiler.hpp` | Compiled, execution-ready Luau. |
| [`DataFile`](../classes/luau_datafile.md) | `luau/datafile.hpp` | Parses and writes `.luau` files that are a single `return { ... }`. |
| [`DataFileError`](../classes/luau_datafile.md#datafileerror) | `luau/datafile.hpp` | Thrown by `DataFile`. |
| [`DataValue`](../classes/luau_datavalue.md) | `luau/datafile.hpp` | A literal Luau value: nil, boolean, number, string or table. |
| [`Environment`](../classes/luau_environment.md) | `luau/environment.hpp` | A set of globals to load into a VM. |
| [`EnvNamespace`](../classes/luau_environment.md#envnamespace) | `luau/environment.hpp` | A table of globals inside an `Environment`. |
| [`Global`](../classes/luau_global.md) | `luau/environment.hpp` | One global value: a function, string, number, boolean, namespace or custom type. |
| [`ModuleLoader`](../classes/luau_moduleloader.md) | `module.hpp` | Implements `require` for one VM. |
| [`ModuleSource`](../classes/luau_modulesource.md) | `module.hpp` | Where module bytecode comes from (abstract). |
| [`FileSystemSource`](../classes/luau_modulesource.md#filesystemsource) | `module.hpp` | Reads and compiles `.luau` files from disk (`sn run`). |
| [`MemorySource`](../classes/luau_modulesource.md#memorysource) | `module.hpp` | Precompiled modules held in memory (built programs, tests). |
| [`ModuleError`](../classes/luau_moduleloader.md#moduleerror) | `module.hpp` | Thrown by the module system. |

## Functions

### `normalizePath`

```cpp
[[nodiscard]] std::optional<std::string> normalizePath(std::string_view path);
```

`#include <sonata/core/module.hpp>`

Lexically normalizes an absolute [module path](../classes/luau_moduleloader.md#module-paths):
converts `\` to `/`, drops `.` and empty segments, and resolves `..`. Returns `std::nullopt` if
the path isn't absolute, or if `..` would climb above its root.

```cpp
normalizePath("/a/./b//c/../d.luau"); // "/a/b/d.luau"
normalizePath("C:\\proj\\main.luau"); // "C:/proj/main.luau"
normalizePath("relative/path");       // std::nullopt
```

### `toGlobal` / `toNamespace`

```cpp
[[nodiscard]] Global toGlobal(const DataValue& value);
[[nodiscard]] EnvNamespace toNamespace(const DataValue& table);
```

`#include <sonata/core/luau/environment.hpp>`

Bridge from [`DataFile`](../classes/luau_datafile.md) to [`Environment`](../classes/luau_environment.md):
turns data read from a `return { ... }` file into globals. See
[`Environment`](../classes/luau_environment.md#loading-data-files-as-globals).

### `customSelf` / `makeCustomGlobal`

Helpers for exposing C++ objects as Luau userdata. See [`Global`](../classes/luau_global.md#custom-types).
