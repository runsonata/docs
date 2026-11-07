---
hide:
  - toc
---

# C++ API Reference

Sonata is a C++20 codebase built into one program, `sn`, which is both the command line and the
runtime of everything it builds. This section documents the code's headers. Use it to add a
built-in library or to work on Sonata itself.

!!! note

    This documentation describes the **C++ API**, not the Luau API. For the built-in modules
    and globals, see the [module API reference](../module/index.md).

## Namespaces

| Namespace | Header | Contents |
|---|---|---|
| [`sonata`](namespaces/sonata.md) | `project/*.hpp`, `runtime/pocket.hpp` | Projects, the package manager, assets, library selection. |
| [`sonata::luau`](namespaces/luau.md) | `luau/*.hpp`, `runtime/module.hpp` | The VM, the compiler, data files, environments and the module system. |
| [`sonata::lib`](namespaces/lib.md) | `runtime/library.hpp` | Built-in libraries and their registry. |
| [`sonata::sched`](namespaces/sched.md) | `runtime/scheduler.hpp` | The task scheduler. |
| [`sonata::runtime`](namespaces/runtime.md) | `runtime/program.hpp` | Running a program the way `sn run` and built executables do. |
| [`sonata::bundle`](namespaces/bundle.md) | `bundle/*.hpp` | The format of programs made by `sn build`, and the runtimes they start from. |
| [`sonata::os`](namespaces/os.md) | `base/os.hpp` | Small OS helpers. |
| [`sonata::paths`](namespaces/paths.md) | `base/paths.hpp` | Where Sonata keeps its files. |
| [`sonata::text`](namespaces/text.md) | `base/text.hpp` | Small string helpers. |
| [`sonata::info`](namespaces/info.md) | `base/info.hpp` | Version and build metadata. |
| [`sonata::cli`](namespaces/cli.md) | `cli/*.hpp` | The `sn` command line. |
| [`sonata::doctor`](namespaces/doctor.md) | `cli/doctor/doctor.hpp` | The checks behind `sn doctor`. |

Core headers live in `source/core/sonata/`, so they're included as
`#include <sonata/project/project.hpp>`. The command line's are in `source/cli/sonata/cli/` and are
included as `#include <sonata/cli/command.hpp>`. Each layer's headers are only visible to what links
it, so nothing in the core can reach the command line.

## Source layout

```
source/core/sonata/base/      version info, OS helpers, text helpers
source/core/sonata/luau/      VM, compiler, data files, environments
source/core/sonata/runtime/   modules, scheduler, library registry, running programs
source/core/sonata/project/   manifests, library selection, require scanning
source/core/sonata/bundle/    the bundle format and build targets
source/libs/<name>/           the built-in libraries (@sonata/*)
source/cli/sonata/cli/        the sn command line: UI, commands, doctor
source/app/main.cpp           sn itself
source/cmake/                 build helpers and templates for generated files
source/tests/                 tests (doctest); library tests live with their library
source/external/              Luau, zlib, Mbed TLS, zstd, libsodium and doctest, as git submodules
```

## Using Sonata from C++

### With CMake

Add Sonata's `source` folder to your build, and link `sonata_core`:

```cmake
add_subdirectory(external/sonata/source EXCLUDE_FROM_ALL)
target_link_libraries(my_app PRIVATE sonata_core)
```

`sonata_core` holds everything a running program needs, every built-in library included, and it
brings in Luau (`Luau.VM`, `Luau.Compiler`, `Luau.Ast`). `EXCLUDE_FROM_ALL` builds only what your
target needs, not `sn` as well. When Sonata isn't the top-level project, its tests are off.

Sonata has no CMake package to `find_package`: only `sn` itself gets installed.

### Running a script

This runs `main.luau` exactly as `sn run` would, with `require`, the `sonata` and `args`
globals, the scheduler and every built-in library:

```cpp
#include <filesystem>
#include <iostream>
#include <memory>
#include <string>
#include <vector>

#include <sonata/runtime/module.hpp>
#include <sonata/runtime/program.hpp>

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
