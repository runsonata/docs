# <code><a href="../sonata">sonata</a>::bundle</code> (namespace)

The format of programs made by `sn build`, functions to read and write it, and the runtimes it
starts from.

`#include <sonata/bundle/bundle.hpp>`, and `<sonata/bundle/target.hpp>` for [runtimes](#runtimes).

## Format

A built program is the `sn` executable with a bundle appended to it:

```
[ runtime executable ][ payload ][ trailer (32 bytes) ]
```

At startup the runtime reads its own file, finds the trailer at the very end, and runs the
program in the payload. Executable loaders ignore data after the end of an executable, so the
runtime itself is untouched.

**Trailer** (little-endian):

| Size | Field |
|---|---|
| u64 | Stored payload size (the bytes right before the trailer). |
| u64 | Payload size once decompressed. |
| u32 | CRC-32 of the stored payload. |
| u32 | Flags. Bit 0: the payload is zlib-compressed. |
| 8 bytes | Magic `"SNBUNDLE"`. |

**Payload** (after decompression): `"SNPK"`, a u32 format version, then the fields of
[`Bundle`](#bundle) in declaration order. Strings and byte blobs are a u32 length followed by
the bytes; lists are a u32 count followed by the items.

**Paths** in a bundle are module paths under a virtual root: the project is `/`, its files
`/main.luau`, `/src/util.luau`, and dependency `foo` is `/.sonata/deps/foo` (the same layout as
on disk).

## Structs

### `Bundle`

```cpp
struct Bundle {
    std::string name;    // manifest name
    std::string version; // manifest version
    std::string entry;   // module path of the entry script

    std::vector<std::string> libraries; // built-in libraries the program may require, sorted
    std::string libraryHint;            // what to tell a script that requires any other one

    // "@name" -> directory, registered like PackageManager::registerAliases().
    std::vector<std::pair<std::string, std::string>> aliases;

    std::vector<Package> packages;
    std::vector<Module> modules;
    std::vector<Asset> assets;
};
```

### `Module`

```cpp
struct Module {
    std::string path; // e.g. "/src/util.luau"
    luau::Bytecode bytecode;
};
```

### `Package`

```cpp
struct Package {
    std::string root;                      // "/" or "/.sonata/deps/<name>"
    std::vector<std::string> dependencies; // names its manifest declares
    std::string entrypoint;                // as written in its manifest
};
```

### `Asset`

```cpp
struct Asset {
    std::string package; // root of the package it belongs to
    std::string path;    // relative to that root, e.g. "assets/logo.png"
    std::string data;
};
```

### `BundleError`

```cpp
class BundleError : public std::runtime_error;
```

## Functions

### `encode`

```cpp
std::string encode(const Bundle& bundle, bool compress);
```

The bytes to append to a runtime: payload plus trailer.

### `read`

```cpp
std::optional<Bundle> read(const std::filesystem::path& executable);
```

Reads the bundle at the end of `executable`. Returns `std::nullopt` if there is none (a plain
runtime); throws `BundleError` if there is one but it is damaged.

### `write`

```cpp
void write(const std::filesystem::path& runtime, const std::filesystem::path& output,
           const Bundle& bundle, bool compress);
```

Writes `runtime` followed by the bundle to `output` (replacing it), and marks it executable.
Throws `BundleError`, including when `runtime` already carries a bundle.

### `formatVersion`

```cpp
std::uint32_t formatVersion();
```

The format version this `sn` reads and writes.

### `readStamp`

```cpp
struct Stamp {
    std::uint32_t format = 0;
    std::string version;
    std::string platform;
};

std::optional<Stamp> readStamp(const std::filesystem::path& executable);
```

Every `sn` embeds a stamp saying what it is, so a runtime for another platform can be checked
without running it: `SONATA-RUNTIME|<bundle format>|<sonata version>|<platform>|`. Returns
`std::nullopt` if `executable` isn't a Sonata runtime.

## Runtimes

`sn build` never compiles a runtime: a runtime is simply an `sn` executable. For this machine's
platform that's the running `sn`, and for another platform it's the `sn` from that platform's
release, kept in `$SONATA_HOME/runtimes/<version>/<target>/`. A runtime must have the same version
as the `sn` doing the build, because the bytecode and the bundle format are only promised to match
within a version.

```cpp
const std::vector<std::string>& knownTargets();
bool isWindowsTarget(std::string_view target);
std::optional<std::filesystem::path> installedRuntimePath(const std::string& target);

struct Runtime {
    std::filesystem::path path;
    std::string target;
    std::string origin; // for humans: "this sn", "installed runtime", "--runtime"
};

Runtime resolveRuntime(const std::optional<std::string>& target, const std::optional<std::filesystem::path>& file);
```

| Function | Description |
|---|---|
| `knownTargets()` | Every platform Sonata releases for. |
| `isWindowsTarget(target)` | Whether programs for `target` need `.exe`. |
| `installedRuntimePath(target)` | Where the runtime for `target` belongs. `std::nullopt` without a home directory. |
| `resolveRuntime(target, file)` | Picks the runtime for a build. `target` is `--target` and `file` is `--runtime`; both are optional. Throws `BundleError` saying what to do if there is no usable one. |

## Example

Inspecting a built program:

```cpp
if (auto bundle = sonata::bundle::read("dist/app")) {
    std::cout << bundle->name << ' ' << bundle->version << '\n'
              << bundle->modules.size() << " modules, "
              << bundle->assets.size() << " assets\n";
    for (const auto& lib : bundle->libraries)
        std::cout << "  @sonata/" << lib << '\n';
}
```
