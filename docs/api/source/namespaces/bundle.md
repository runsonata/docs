# <code><a href="../sonata">sonata</a>::bundle</code> (namespace)

The format of programs made by `sn build`, functions to read and write it, and the runtimes it
starts from.

`#include <sonata/bundle/bundle.hpp>`, and `<sonata/bundle/target.hpp>` for [runtimes](#runtimes).

## Format

A built program is the `sn` executable with a bundle appended to it:

```
[ runtime executable ][ assets ][ payload ][ trailer (32 bytes) ]
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

**Assets** aren't in the payload, which is read whole at startup. Each one is stored on its own
before it, and read only when a script asks for it, a piece at a time
([`AssetReader`](#assetreader)). With compression, an asset is a zlib stream unless that wouldn't
make it smaller. The payload lists them after the modules: a u64, the size of the asset area
(which ends where the payload starts), then for each asset:

| Size | Field |
|---|---|
| string | Package root. |
| string | Path. |
| u64 | Size. |
| u32 | Flags. Bit 0: stored as a zlib stream. Bit 1: executable. |
| u64 | Offset from the start of the asset area. |
| u64 | Stored size. |
| u32 | CRC-32 of the contents (not of what's stored). |

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
    std::vector<std::string> without;   // optional features it leaves out, sorted

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
    std::string package;     // root of the package it belongs to
    std::string path;        // relative to that root, e.g. "assets/logo.png"
    std::uint64_t size = 0;  // set by read(); write() measures it
    bool executable = false; // pocket.copy gives the copy the executable bit

    // Writing: the contents come from "file" if it's set, from "data" otherwise.
    std::filesystem::path file;
    std::string data;

    // Reading: where read() found it. Open it with AssetReader.
    AssetLocation location;
};
```

Given to [`write`](#write), an asset names its contents: a `file`, which is copied a piece at a
time, or `data`. Returned by [`read`](#read), it says where they are.

### `AssetLocation`

```cpp
struct AssetLocation {
    std::uint64_t offset = 0; // from the start of the file
    std::uint64_t stored = 0; // bytes in the file
    std::uint32_t crc = 0;    // CRC-32 of the contents, not of what's stored
    bool compressed = false;  // stored as a zlib stream
};
```

### `BundleError`

```cpp
class BundleError : public std::runtime_error;
```

## Functions

### `read`

```cpp
std::optional<Bundle> read(const std::filesystem::path& executable);
```

Reads the bundle at the end of `executable`. Returns `std::nullopt` if there is none (a plain
runtime); throws `BundleError` if there is one but it is damaged. Assets are only located, not
read.

### `write`

```cpp
void write(const std::filesystem::path& runtime, const std::filesystem::path& output,
           const Bundle& bundle, bool compress);
```

Writes `runtime` followed by the bundle to `output` (replacing it), and marks it executable.
Assets are copied a piece at a time, so they never have to fit in memory. `compress` compresses
the payload, and each asset that comes out smaller for it. Throws `BundleError`, including when
`runtime` already carries a bundle.

### `AssetReader`

```cpp
class AssetReader {
public:
    AssetReader(const std::filesystem::path& executable, const Asset& asset);
    std::size_t read(char* out, std::size_t max);
};
```

An asset's contents, a piece at a time, from the program [`read`](#read) found it in. The
constructor throws `BundleError` if `executable` can't be opened. `read` puts up to `max` (at
least 1) bytes into `out` and returns how many, 0 only at the end. The checksum is checked when
the last byte comes out, so a damaged asset throws `BundleError` there, if not before.

```cpp
const auto program = bundle::read(executable);
bundle::AssetReader reader(executable, program->assets[0]);
char piece[65536];
for (std::size_t got; (got = reader.read(piece, sizeof(piece))) > 0;) {
    out.write(piece, got);
}
```

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
    std::vector<std::string> features; // optional features it's built with, sorted
};

std::optional<Stamp> readStamp(const std::filesystem::path& executable);
```

Every `sn` embeds a stamp saying what it is, so a runtime for another platform can be checked
without running it: `SONATA-RUNTIME|<bundle format>|<sonata version>|<platform>|<features>|`,
where `<features>` is like `tls+zstd`, or `none`. Returns `std::nullopt` if `executable` isn't a
Sonata runtime. The stamp is generated per runtime (`cmake/variant.cpp.in`) as one literal, so it
can be found in the file.

## Runtimes

`sn build` never compiles a runtime: a runtime is simply an `sn` executable. For this machine's
platform that's the running `sn`, and for another platform it's the `sn` from that platform's
release, kept in `$SONATA_HOME/runtimes/<version>/<target>/`. A runtime must have the same version
as the `sn` doing the build, because the bytecode and the bundle format are only promised to match
within a version.

Runtimes also differ in their [optional features](runtime.md#optional-features). `sn` and
`<target>/sn` have them all; `<target>/<features>/sn` (like `tls+zstd/sn` or `none/sn`) only
those. A build takes the installed runtime with the fewest features that has every one the program
needs, and the program turns off the rest (`Bundle::without`), so it behaves the same whichever
runtime carries it.

```cpp
const std::vector<std::string>& knownTargets();
bool isWindowsTarget(std::string_view target);
std::optional<std::filesystem::path> installedRuntimePath(const std::string& target);
std::optional<std::filesystem::path> installedVariantPath(const std::string& target,
                                                          const std::vector<std::string>& features);
std::string variantName(const std::vector<std::string>& features);

struct Runtime {
    std::filesystem::path path;
    std::string target;
    std::string origin;                // for humans: "this sn", "installed runtime", "--runtime"
    std::vector<std::string> features; // what it's built with, sorted
    std::vector<std::string> unneeded; // of those, what the program doesn't need (it's turned off)
    std::string note;                  // a warning for the user, or ""
};

Runtime resolveRuntime(const std::optional<std::string>& target, const std::optional<std::filesystem::path>& file,
                       const std::vector<std::string>& features);
```

| Function | Description |
|---|---|
| `knownTargets()` | Every platform Sonata releases for. |
| `isWindowsTarget(target)` | Whether programs for `target` need `.exe`. |
| `installedRuntimePath(target)` | Where the runtime for `target` with every feature belongs. `std::nullopt` without a home directory. |
| `installedVariantPath(target, features)` | Where the runtime for `target` with exactly `features` belongs. |
| `variantName(features)` | `"tls+zstd"`, or `"none"`: how stamps and folders name a set of features. |
| `resolveRuntime(target, file, features)` | Picks the runtime for a build. `target` is `--target` and `file` is `--runtime`, both optional; `features` are the ones the program needs. If the exact runtime isn't installed, it takes a fuller one and says so in `note`. Throws `BundleError` saying what to do if there is no usable one. |

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
