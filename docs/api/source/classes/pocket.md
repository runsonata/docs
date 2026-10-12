# <code><a href="../../namespaces/sonata">sonata</a>::Pocket</code> (Class)

Read-only files that travel with a program: whatever a package lists in `build.assets`. Scripts
read them through [`@sonata/pocket`](../../module/pocket.md). `sn run` reads them from disk
([`DiskPocket`](#diskpocket)), and a built program from memory ([`MemoryPocket`](#memorypocket)).
Either way only the declared files are visible.

`#include <sonata/core/pocket.hpp>`

Every package (the project and each dependency) has its own assets, and a script sees those of
the package it belongs to. Packages are identified by the module path of their root folder (see
[module paths](luau_moduleloader.md#module-paths)): `"/"` and `"/.sonata/deps/foo"` in a built
program, real absolute paths under `sn run`. Asset paths are relative to that root, use `/`, and
never contain `.` or `..` segments.

## Definition

```cpp
class Pocket {
public:
    virtual ~Pocket() = default;

    virtual std::optional<std::string> read(const std::string& package, const std::string& path) const = 0;
    virtual std::vector<std::string> list(const std::string& package) const = 0;
    virtual bool bundled() const = 0;

    std::optional<std::string> packageOf(std::string_view modulePath) const;

    static std::optional<std::string> normalize(std::string_view path);
    static void install(lua_State* L, const Pocket* pocket);
    static const Pocket* of(lua_State* L);

protected:
    void addRoot(std::string package);
};
```

## Methods

| Method | Description |
|---|---|
| `read(package, path)` | The contents of an asset, or `std::nullopt` if the package has no such asset. |
| `list(package)` | Every asset of the package, sorted. |
| `bundled()` | True when the assets come from a built executable. |
| `packageOf(modulePath)` | The innermost package containing the module, or the first package added if none does. |
| `normalize(path)` | Turns a path written by a script into the canonical form: `"./assets\\a.txt"` becomes `"assets/a.txt"`. `std::nullopt` if it is empty, absolute, or climbs out of the package. |
| `install(L, pocket)` | Makes `pocket` the one `@sonata/pocket` uses in this VM. The pocket must outlive the VM. Without one, every pocket function raises. |
| `of(L)` | The pocket installed in this VM, or `nullptr`. |
| `addRoot(package)` | For subclasses: records a package root, in order. |

[`runtime::runProgram`](../namespaces/runtime.md#runprogram) calls `install` for you.

## `DiskPocket`

```cpp
class DiskPocket final : public Pocket {
public:
    void addPackage(const std::string& package, std::filesystem::path directory,
                    const std::vector<std::string>& assets);
};
```

`sn run`: reads the declared files from each package's folder on demand. `assets` is the
package's `build.assets` (files or folders). `bundled()` is `false`.

```cpp
sonata::DiskPocket pocket;
pocket.addPackage(rootModulePath, project.root(), project.manifest().build.assets);
```

## `MemoryPocket`

```cpp
class MemoryPocket final : public Pocket {
public:
    void addPackage(const std::string& package);
    void add(const std::string& package, const std::string& path, std::string data);
};
```

A built program: every asset was read into memory from the executable. `bundled()` is `true`.

## `collectAssets`

```cpp
std::vector<std::string> collectAssets(const std::filesystem::path& directory,
                                       const std::vector<std::string>& assets);
```

Expands `build.assets` for the package in `directory`: every regular file the entries name
(folders recursively, skipping any `.sonata` folder), as asset paths, sorted and without
duplicates. Throws `std::runtime_error` if an entry doesn't exist. `sn build` uses it to decide
what to pack.
