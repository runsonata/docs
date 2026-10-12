---
hide:
  - toc
---

# C++ API Reference

Sonata is a C++20 library (`sonata`) with two small programs on top: the CLI (`sn`) and the
runtime (`snrt`). This section documents the library's public headers. Use it to embed Sonata
in your own program, to add a built-in library, or to work on Sonata itself.

!!! note

    This documentation describes the **C++ API**, not the Luau API. For the built-in modules
    and globals, see the [module API reference](../module/index.md).

## Namespaces

| Namespace | Header | Contents |
|---|---|---|
| [`sonata`](namespaces/sonata.md) | `project.hpp`, `package.hpp`, `pocket.hpp`, `selection.hpp` | Projects, the package manager, assets, library selection. |
| [`sonata::luau`](namespaces/luau.md) | `luau/*.hpp`, `module.hpp` | The VM, the compiler, data files, environments and the module system. |
| [`sonata::lib`](namespaces/lib.md) | `library.hpp` | Built-in libraries and their registry. |
| [`sonata::sched`](namespaces/sched.md) | `scheduler.hpp` | The task scheduler. |
| [`sonata::runtime`](namespaces/runtime.md) | `runtime.hpp` | Running a program the way `sn run` and built executables do. |
| [`sonata::bundle`](namespaces/bundle.md) | `bundle.hpp` | The format of programs made by `sn build`. |
| [`sonata::os`](namespaces/os.md) | `system.hpp` | Small OS helpers. |
| [`sonata::info`](namespaces/info.md) | `info.hpp` | Version and build metadata. |
| [`sonata::cli`](namespaces/cli.md) | `cli/cli.hpp`, `cli/command.hpp` | The `sn` command-line interface (not installed). |

All headers live in `include/sonata/core/`, so they are included as
`#include <sonata/core/project.hpp>`.

## Source layout

```
include/sonata/core/   public headers
src/core/              the library: projects, packages, modules, scheduler, ...
src/core/luau/         VM, compiler, data files, environments
src/core/libs/         the built-in libraries (@sonata/*)
cli/                   sn: the command-line interface and its commands
runtime/               snrt: the runtime that "sn build" turns into programs
cmake/                 templates for generated files
tests/                 unit tests (doctest)
external/              Luau and doctest, as git submodules
```

## Using Sonata from C++

### With CMake

The simplest way is to add Sonata's source tree to your build. When it isn't the top-level
project, the CLI, runtime, tests and install rules are off by default:

```cmake
add_subdirectory(external/sonata)
target_link_libraries(my_app PRIVATE sonata::sonata)
```

An installed Sonata (with `SONATA_INSTALL`) provides a CMake package. Its exported targets link
to zlib and OpenSSL, so find those first:

```cmake
find_package(ZLIB REQUIRED)
find_package(OpenSSL REQUIRED)
find_package(sonata REQUIRED)
target_link_libraries(my_app PRIVATE sonata::sonata)
```

Linking `sonata::sonata` also brings in Luau (`Luau.VM`, `Luau.Compiler`, `Luau.Ast`,
`Luau.Common`) and sets the compile definitions [`sonata::info`](namespaces/info.md) relies on.

### Running a script

This runs `main.luau` exactly as `sn run` would, with `require`, the `sonata` and `args`
globals, the scheduler and every built-in library:

```cpp
#include <filesystem>
#include <iostream>
#include <memory>
#include <string>
#include <vector>

#include <sonata/core/module.hpp>
#include <sonata/core/runtime.hpp>

int main(int argc, char** argv) {
    namespace fs = std::filesystem;
    using namespace sonata;

    // The loader must outlive the VM that runProgram() creates.
    luau::ModuleLoader loader(std::make_unique<luau::FileSystemSource>());

    runtime::ProgramInfo info;
    info.name = "embedded";
    info.version = "1.0.0";
    info.root = fs::current_path().generic_string();
    info.entry = *luau::normalizePath(fs::absolute("main.luau").generic_string());

    std::vector<std::string> args(argv + 1, argv + argc);

    try {
        runtime::runProgram(loader, info, args, /*pocket=*/nullptr);
    } catch (const luau::ModuleError& error) {
        std::cerr << error.what() << '\n'; // message and stack trace
        return 1;
    }
}
```

See [`runtime::runProgram`](namespaces/runtime.md) for what it sets up, and
[`ModuleLoader`](classes/luau_moduleloader.md) for aliases and library restrictions.

### Lower level

To work with a bare VM instead, use [`VM`](classes/luau_vm.md),
[`Compiler`](classes/luau_compiler.md) and [`Environment`](classes/luau_environment.md)
directly:

```cpp
sonata::luau::VM vm;
sonata::luau::Compiler compiler;

sonata::luau::Environment env;
env.setString("greeting", "hello");
env.load(vm);

sonata::luau::Bytecode code = compiler.compile("print(greeting)");
if (auto error = code.compileError()) {
    std::cerr << *error << '\n';
} else {
    vm.execute(code);
}
```

## Extending Sonata

- [Writing a built-in library](writing-a-library.md): add a `@sonata/<name>` module in C++.
- [`sonata::cli`](namespaces/cli.md#adding-a-command): add an `sn` command.
