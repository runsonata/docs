# <code><a href="../../namespaces/sonata">sonata</a>::<a href="../../namespaces/luau">luau</a>::ModuleSource</code> (Class)

Where module bytecode comes from. The [`ModuleLoader`](luau_moduleloader.md) never touches the
disk (or a packed program) directly; it only talks to one of these. Paths passed in are always
normalized [module paths](luau_moduleloader.md#module-paths).

`#include <sonata/core/module.hpp>`

## Definition

```cpp
class ModuleSource {
public:
    virtual ~ModuleSource() = default;

    virtual bool exists(std::string_view path) const = 0;
    virtual Bytecode load(std::string_view path) const = 0;

    virtual std::optional<std::vector<std::string>> dependencyNames(std::string_view directory) const;
    virtual std::optional<std::string> packageEntrypoint(std::string_view directory) const;
};
```

## Methods

### `exists`

```cpp
virtual bool exists(std::string_view path) const = 0;
```

True if a module file exists at exactly this path.

### `load`

```cpp
virtual Bytecode load(std::string_view path) const = 0;
```

The module's bytecode. Throws on failure, ideally a [`ModuleError`](luau_moduleloader.md#moduleerror).

### `dependencyNames`

```cpp
virtual std::optional<std::vector<std::string>> dependencyNames(std::string_view directory) const;
```

The names of the dependencies declared in the manifest of the package rooted at `directory`
(`<directory>/.sonata/project.luau`). This is what lets `@name` work inside a package for the
dependencies it declares itself.

Returns `std::nullopt` if `directory` isn't a package root, and throws if there is a manifest but
it can't be read. The default says "not a package" for every folder, so a source that doesn't
override it still works; it only gets the aliases registered with `ModuleLoader::addAlias()`.

### `packageEntrypoint`

```cpp
virtual std::optional<std::string> packageEntrypoint(std::string_view directory) const;
```

The `entrypoint` the manifest of the package rooted at `directory` names, exactly as written
(e.g. `"src/init.luau"`). Requiring the folder itself loads that file instead of `init.luau`.
`std::nullopt` if `directory` isn't a package root or names no entrypoint. The default says "not
a package".

## `FileSystemSource`

```cpp
class FileSystemSource final : public ModuleSource;
```

What `sn run` uses: reads `.luau` files from disk and compiles them on demand with a default
[`Compiler`](luau_compiler.md). `dependencyNames` and `packageEntrypoint` read
`<directory>/.sonata/project.luau` through [`Project::open`](project.md#open).

## `MemorySource`

```cpp
class MemorySource final : public ModuleSource {
public:
    void add(std::string_view path, Bytecode bytecode);
    void addPackage(std::string_view directory,
                    std::vector<std::string> dependencies,
                    std::string entrypoint = {});
};
```

Precompiled modules held in memory, keyed by virtual path. Built programs fill one from their
[bundle](../namespaces/bundle.md) at startup; it is also handy for tests.

| Method | Description |
|---|---|
| `add(path, bytecode)` | Adds a module. `path` is rooted at `/`, so `"src/util.luau"` and `"/src/util.luau"` are the same. Throws `std::invalid_argument` if the path climbs above the root. |
| `addPackage(directory, dependencies, entrypoint)` | Records that `directory` (rooted at `/`) is a package whose manifest declares these dependencies and, if not empty, this entrypoint. Use `"/"` for the project and e.g. `"/.sonata/deps/foo"` for a dependency. |

```cpp
using namespace sonata::luau;

Compiler compiler;
auto source = std::make_unique<MemorySource>();
source->add("/main.luau", compiler.compile("return require('./util').answer"));
source->add("/util.luau", compiler.compile("return { answer = 42 }"));

ModuleLoader loader(std::move(source));
VM vm;
loader.install(vm);
loader.run(vm, "/main.luau");
```

## Writing your own

Implement `exists` and `load` (and optionally the two package hooks) to serve modules from
anywhere: an archive, a database, the network.

```cpp
class ZipSource final : public sonata::luau::ModuleSource {
public:
    explicit ZipSource(Zip zip) : zip_(std::move(zip)) {}

    bool exists(std::string_view path) const override {
        return zip_.contains(path);
    }

    sonata::luau::Bytecode load(std::string_view path) const override {
        auto bytecode = compiler_.compile(zip_.read(path));
        if (auto error = bytecode.compileError())
            throw sonata::luau::ModuleError(std::string(path) + *error);
        return bytecode;
    }

private:
    Zip zip_;
    sonata::luau::Compiler compiler_;
};
```
