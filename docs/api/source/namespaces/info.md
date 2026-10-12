# <code><a href="../sonata">sonata</a>::info</code> (namespace)

The single source of truth for Sonata's identity and build metadata.

`#include <sonata/core/info.hpp>`

Everything here is `inline constexpr` (or an inline function), filled in from compile
definitions that `src/CMakeLists.txt` sets as **PUBLIC** on the `sonata` target. They are public
on purpose: the library, the CLI and any program linking Sonata must all see the same values,
otherwise it's an ODR violation.

## Identity

| Name | Value |
|---|---|
| `name` | `"Sonata"` |
| `id` | `"sonata"` |
| `binary` | `"sn"` |
| `tagline` | `"All-in-one Luau toolkit"` |

## Version

```cpp
struct Version {
    int major;
    int minor;
    int patch;
    std::string_view pre; // pre-release tag, e.g. "alpha.1"; empty for a stable release
};

inline constexpr Version version;
```

| Name | Description |
|---|---|
| `version` | The version, from `project(sonata VERSION x.y.z)` in the root `CMakeLists.txt`. |
| `version_string()` | `"0.1.8"`, or `"0.1.8-alpha.1"` with a pre-release tag. |
| `git_hash` | The short commit hash Sonata was built from, or `""`. |
| `luau_version` | `git describe --tags` of the Luau submodule, or `""`. |

## Build

| Name | Description |
|---|---|
| `build_type` | The lowercase CMake configuration: `"debug"`, `"release"`, `"relwithdebinfo"`, ... Falls back to `"release"` or `"debug"` (from `NDEBUG`) when CMake gave none. |
| `is_debug` | `build_type == "debug"`. |
| `platform_string()` | `"<os>-<arch>"`: `"linux-x64"`, `"macos-arm64"`, `"windows-x64"`, ... (`"unknown"` parts for anything else). |
| `compiler_string()` | `"gcc 13.2.0"`, `"clang 17.0.6"`, `"msvc 1939"`. |

## Compile definitions

Anything left undefined falls back to a default.

| Definition | Default | Set from |
|---|---|---|
| `SONATA_VERSION_MAJOR`, `_MINOR`, `_PATCH` | `0`, `1`, `0` | `project(... VERSION x.y.z)` |
| `SONATA_VERSION_PRE` | `""` | `set(SONATA_VERSION_PRE "alpha.1")` in the root `CMakeLists.txt` |
| `SONATA_GIT_HASH` | `""` | `git rev-parse --short HEAD` |
| `SONATA_LUAU_VERSION` | `""` | `git describe --tags` in `external/luau` |
| `SONATA_BUILD_TYPE` | `""` | `$<LOWER_CASE:$<CONFIG>>` |

These values are what `sn --version --verbose` prints, and what
[`@sonata/sonata`](../../module/sonata.md#sonatainfo) exposes as `sonata.info`.
