# <code><a href="../../namespaces/sonata">sonata</a>::Pocket</code> (Class)

Read-only files that travel with a program: whatever a package lists in `build.assets`. Scripts
read them through [`@sonata/pocket`](../../module/pocket.md). `sn run` reads them from disk
([`DiskPocket`](#diskpocket)), and a built program from its own executable
([`BundlePocket`](#bundlepocket)). Either way only the declared files are visible, and they're
read a piece at a time, so an asset never has to fit in memory.

`#include <sonata/runtime/pocket.hpp>`

Every package (the project and each dependency) has its own assets, and a script sees those of
the package it belongs to. Packages are identified by the module path of their root folder (see
[module paths](luau_moduleloader.md#module-paths)): `"/"` and `"/.sonata/deps/foo"` in a built
program, real absolute paths under `sn run`. Asset paths are relative to that root, use `/`, and
never contain `.` or `..` segments.

## Definition

```cpp
struct AssetInfo {
    std::uint64_t size = 0;
    bool executable = false; // a copy should get the executable bit
};

class AssetStream {
public:
    virtual ~AssetStream() = default;
    virtual std::size_t read(char* out, std::size_t max) = 0;
};

class Pocket {
public:
    virtual ~Pocket() = default;

    virtual std::optional<AssetInfo> stat(const std::string& package, const std::string& path) const = 0;
    virtual std::unique_ptr<AssetStream> open(const std::string& package, const std::string& path) const = 0;
    virtual std::vector<std::string> list(const std::string& package) const = 0;
    virtual bool bundled() const = 0;

    std::optional<std::string> read(const std::string& package, const std::string& path,
                                    std::uint64_t max = std::numeric_limits<std::uint64_t>::max()) const;
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
| `stat(package, path)` | The asset's size and whether it's executable, or `std::nullopt` if the package has no such asset. |
| `open(package, path)` | Opens an asset for reading; `nullptr` if the package has no such asset. `AssetStream::read` puts up to `max` (at least 1) bytes into `out` and returns how many, 0 only at the end; it throws `std::runtime_error` if the asset can't be read. |
| `read(package, path, max)` | The whole asset, through `open`, or `std::nullopt` if there is no such asset. Throws `std::length_error` once it's longer than `max`. |
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

## `BundlePocket`

```cpp
class BundlePocket final : public Pocket {
public:
    explicit BundlePocket(std::filesystem::path executable);

    void addPackage(const std::string& package);
    void add(bundle::Asset asset);
};
```

A built program: the assets stay in `executable`, located by
[`bundle::read`](../namespaces/bundle.md#read), and each is read from it only when a script asks
(through [`bundle::AssetReader`](../namespaces/bundle.md#assetreader)). `bundled()` is `true`.

## `MemoryPocket`

```cpp
class MemoryPocket final : public Pocket {
public:
    void addPackage(const std::string& package);
    void add(const std::string& package, const std::string& path, std::string data, bool executable = false);
};
```

Assets held in memory, for tests. `bundled()` is `true`.

## `collectAssets`

```cpp
std::vector<std::string> collectAssets(const std::filesystem::path& directory,
                                       const std::vector<std::string>& assets);
```

Expands `build.assets` for the package in `directory`: every regular file the entries name
(folders recursively, skipping any `.sonata` folder), as asset paths, sorted and without
duplicates. Throws `std::runtime_error` if an entry doesn't exist. `sn build` uses it to decide
what to pack.
