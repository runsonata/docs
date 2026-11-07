# <code><a href="../sonata">sonata</a>::info</code> (namespace)

The single source of truth for Sonata's identity and build metadata.

`#include <sonata/base/info.hpp>`

The version lives in one place: `project(sonata VERSION ...)` in `source/CMakeLists.txt`, with the
pre-release tag in `SONATA_VERSION_PRE` next to it. Values that change with every build are
generated into one small file from `cmake/info.cpp.in`, so that bumping the version or moving to a
new commit recompiles one file, not the project.

## Identity

| Name | Value |
|---|---|
| `name` | `"Sonata"` |
| `id` | `"sonata"` |
| `binary` | `"sn"` |
| `tagline` | `"All-in-one Luau toolkit"` |
| `website` | `"https://sonata.5418.org"` |
| `docsUrl` | `"https://sonata.5418.org/docs"` |

All of these are `inline constexpr std::string_view`.

## Build

```cpp
std::string_view version();
std::string_view gitHash();
std::string_view luauVersion();
std::string_view buildType();
bool isDebug();
std::string platform();
std::string_view runtimeStamp();
std::string compiler();
```

| Function | Description |
|---|---|
| `version()` | `"2.0.0"`, or `"2.0.0-dev.2"` with a pre-release tag. |
| `gitHash()` | The short commit hash Sonata was built from. May be empty. |
| `luauVersion()` | `git describe --tags --always` of the Luau submodule. May be empty. |
| `buildType()` | `"debug"` or `"release"`. |
| `isDebug()` | Whether this is a debug build. |
| `platform()` | `"<os>-<arch>"`: `"linux-x64"`, `"macos-arm64"`, `"windows-x64"`, ... These are the names release archives and `sn build --target` use. |
| `runtimeStamp()` | What this executable says about itself; see [`readStamp`](bundle.md#readstamp). It has to stay a compile-time literal, or it wouldn't exist in the file for anyone to read. |
| `compiler()` | `"gcc 13.2.0"`, `"clang 17.0.6"`, `"msvc 1939"`. |

These values are what `sn --version --verbose` prints, and what
[`@sonata/sonata`](../../module/sonata.md#sonatainfo) exposes as `sonata.info`.
