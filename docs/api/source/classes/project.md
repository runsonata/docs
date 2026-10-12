# <code><a href="../../namespaces/sonata">sonata</a>::Project</code> (Class)

An opened, structurally valid Sonata project: a folder with a `.sonata/project.luau` manifest
and the entry script it names.

`#include <sonata/core/project.hpp>`

```cpp
sonata::Project project = sonata::Project::find(".");
std::cout << project.manifest().name << " at " << project.root() << '\n';
```

## Opening a project

### `open`

```cpp
static Project open(const std::filesystem::path& root);
```

Opens the project whose root is `root`. The folder must contain `.sonata/project.luau` and the
entrypoint it names (`main.luau` if the manifest doesn't specify one). `.sonata/deps` is
optional.

Throws `std::runtime_error` if the project is invalid, if `project.luau` can't be parsed, or if
it contains an invalid or duplicate dependency. See
[The project manifest](../../../guide/manifest.md#validation-errors) for every check.

### `find`

```cpp
static Project find(const std::filesystem::path& start);
```

Searches `start` and its parents for a `.sonata/project.luau` and opens the first project found.
If `start` is a file, its folder is used. Throws `std::runtime_error` if none is found.

## Paths

| Method | Returns |
|---|---|
| `root()` | The project folder. |
| `entrypoint()` | The resolved, absolute path of the entry script. |
| `sonataDir()` | `<root>/.sonata` |
| `projectFile()` | `<root>/.sonata/project.luau` |
| `dependenciesDir()` | `<root>/.sonata/deps` |
| `hasDependenciesDirectory()` | Whether `.sonata/deps` exists. |

All return `const std::filesystem::path&` (except the last, `bool`) and are `noexcept`.

### `sourceFiles`

```cpp
std::vector<std::filesystem::path> sourceFiles() const;
```

Every `.luau` file in the project, excluding anything inside `.sonata`.

## The manifest

```cpp
const Manifest& manifest() const noexcept;
Manifest& manifest() noexcept;
```

The parsed manifest. The mutable overload lets callers edit it, mainly
`manifest().dependencies`; nothing is written to disk until `saveManifest()`. Changing
`manifest().entrypoint` doesn't update `entrypoint()`, which is only resolved when the project
is opened.

### `saveManifest`

```cpp
void saveManifest() const;
```

Writes the manifest back to `.sonata/project.luau`, replacing it atomically (temp file and
rename), so a failed save leaves the old manifest untouched.

Top-level keys this class doesn't manage (including `build`) are preserved as they were, and a
`--!strict` line is written back if `manifest().strict` is set. Other comments and formatting
are not kept: the file is regenerated.

Throws `std::invalid_argument` if a dependency is invalid or two share a name, and
`std::runtime_error` if the file can't be read or written.

### `findDependency`

```cpp
const Dependency* findDependency(const std::string& name) const noexcept;
```

The dependency called `name`, or `nullptr`.

### `addDependency`

```cpp
bool addDependency(Dependency dependency);
```

Adds a dependency, or replaces the one with the same name, then saves the manifest. Returns
`true` if an existing entry was replaced. Throws `std::invalid_argument` if the dependency is
invalid. If saving fails, the in-memory manifest is rolled back and the exception rethrown.

This only edits the manifest; [`PackageManager::add`](package_manager.md#add) also installs.

### `removeDependency`

```cpp
bool removeDependency(const std::string& name);
```

Removes the dependency and saves the manifest. Returns `false` (doing nothing) if there is no
such dependency. Rolls back on a failed save, like `addDependency`.

## Nested types

### `Manifest`

```cpp
struct Manifest {
    std::string name;
    std::string version;
    std::string description;
    std::vector<std::string> authors;
    std::string entrypoint;               // exactly as written, e.g. "src/init.luau"
    std::vector<Dependency> dependencies; // unique names
    Build build;
    bool strict = false;                  // project.luau starts with "--!strict"
};
```

`strict` turns anything that would only be a warning about this package's build settings (such
as a missing `build.libraries`) into an error. In the root project it applies to every
dependency as well.

### `Dependency`

```cpp
struct Dependency {
    std::string name;
    std::string url;
    std::string ref; // empty = not specified

    std::optional<std::string> validationError() const;
    void validate() const;
    bool sameSource(const Dependency& other) const;
    static std::string normalizeUrl(std::string url);
};
```

One entry of the manifest's `dependencies` array. The rules, enforced by both the manifest
loader and `saveManifest()`:

| Field | Rule |
|---|---|
| `name` | Letters, digits and underscores only; must not start with a digit. |
| `url` | Must not be empty, start with `-`, or contain control characters. |
| `ref` | Optional. Must not start with `-`, contain control characters, `..`, a space, or any of `~ ^ : ? * [ \`. |

The `-` rules make sure a URL or ref can never be mistaken for a command-line option when it is
handed to `git`.

| Method | Description |
|---|---|
| `validationError()` | The first rule this dependency breaks, or `std::nullopt`. |
| `validate()` | Throws `std::invalid_argument` describing the first broken rule. |
| `sameSource(other)` | True if both have the same `ref` and the same URL after `normalizeUrl()`. The name is ignored. |
| `normalizeUrl(url)` | Canonical form of a Git URL: trims whitespace, drops a trailing `/` and `.git`, and lowercases the scheme and host of `scheme://host/...` URLs. The path and user info keep their case. |

### `Build`

```cpp
struct Build {
    std::optional<std::string> output;
    std::optional<std::vector<std::string>> libraries; // nullopt = every library
    std::vector<std::string> assets;
    std::optional<int> optimize;  // 0..2
    std::optional<int> debug;     // 0..2
    std::optional<bool> compress;
    std::optional<bool> standalone;
};
```

The manifest's optional [`build` table](../../../guide/manifest.md#build). Fields left out are
`std::nullopt` (or empty), so callers can tell "not given" from a value. `sn build` reads all of
it; `sn run` uses `libraries` and `assets` too, so a program behaves the same before and after
it is built. A dependency's manifest only contributes `libraries` and `assets`.

Library names aren't checked here (see [`selectLibraries`](../namespaces/sonata.md#selectlibraries)),
so a manifest naming a library this Sonata doesn't know still opens.
