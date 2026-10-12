---
search:
  boost: 6
---

# `sonata` (namespace)

The root namespace. It holds the classes for projects, packages and assets, and every other
namespace.

## Classes & Structs

| Class | Header | Description |
|---|---|---|
| [`Project`](../classes/project.md) | `project.hpp` | An opened, valid Sonata project and its manifest. |
| [`PackageManager`](../classes/package_manager.md) | `package.hpp` | Installs, updates and removes a project's dependencies. |
| [`GitBackend`](../classes/package_manager.md#gitbackend) | `package.hpp` | A way of cloning repositories, used by `PackageManager`. |
| [`InstalledPackage`](../classes/package_manager.md#installedpackage) | `package.hpp` | A package present in `.sonata/deps`. |
| [`PackageError`](../classes/package_manager.md#packageerror) | `package.hpp` | Thrown by the package manager. |
| [`Pocket`](../classes/pocket.md) | `pocket.hpp` | Read-only asset files for `@sonata/pocket`. |
| [`DiskPocket`](../classes/pocket.md#diskpocket) | `pocket.hpp` | Assets read from disk (`sn run`). |
| [`MemoryPocket`](../classes/pocket.md#memorypocket) | `pocket.hpp` | Assets held in memory (built programs). |
| [`InstalledProject`](#installedproject) | `selection.hpp` | An installed dependency, opened as a project. |
| [`LibraryOptions`](#libraryoptions) | `selection.hpp` | Overrides for library selection. |
| [`LibrarySelection`](#libraryselection) | `selection.hpp` | The built-in libraries a program may use. |
| [`BuildError`](#builderror) | `selection.hpp` | Thrown by library selection and `sn build`. |

## Functions

| Function | Header | Description |
|---|---|---|
| [`openDependencies`](#opendependencies) | `selection.hpp` | Opens every package in a project's `.sonata/deps`. |
| [`selectLibraries`](#selectlibraries) | `selection.hpp` | Works out which built-in libraries a program may use. |
| [`collectAssets`](../classes/pocket.md#collectassets) | `pocket.hpp` | Expands `build.assets` into a list of files. |
| [`makeCliGitBackend`, `makeLibGit2Backend`, `defaultGitBackends`](../classes/package_manager.md#git-backends) | `package.hpp` | Create Git backends. |

## Child Namespaces

| Namespace | Description |
|---|---|
| [`sonata::luau`](luau.md) | The VM, the compiler, data files, environments and the module system. |
| [`sonata::lib`](lib.md) | Built-in libraries and their registry. |
| [`sonata::sched`](sched.md) | The task scheduler. |
| [`sonata::runtime`](runtime.md) | Running a program like `sn run` does. |
| [`sonata::bundle`](bundle.md) | The format of programs made by `sn build`. |
| [`sonata::os`](os.md) | Small OS helpers. |
| [`sonata::info`](info.md) | Version and build metadata. |
| [`sonata::cli`](cli.md) | The `sn` command-line interface. |

## Library selection

`#include <sonata/core/selection.hpp>`

Works out which built-in libraries a program may use from the `build.libraries` lists of the
root project and every installed dependency. `sn build` compiles exactly these libraries into
the program, and `sn run` refuses the others. The rules are described in
[The project manifest](../../../guide/manifest.md#buildlibraries):

- The result is the union of all the lists.
- A manifest without `build.libraries` means "every library". For a dependency this is a
  warning, shown only when the root declares a list.
- A `--!strict` manifest turns its own missing list into an error; a strict root does the same
  for every dependency.
- A name Sonata doesn't know is always an error.

### `BuildError`

```cpp
class BuildError : public std::runtime_error;
```

Thrown by `openDependencies`, `selectLibraries` and `sn build`.

### `InstalledProject`

```cpp
struct InstalledProject {
    std::string name; // folder name, i.e. what "@name" refers to
    Project project;
};
```

### `openDependencies`

```cpp
std::vector<InstalledProject> openDependencies(const Project& root);
```

Opens every package in `root`'s `.sonata/deps` (skipping `.staging`), sorted by name. Throws
`BuildError` if one of them isn't a valid project.

### `LibraryOptions`

```cpp
struct LibraryOptions {
    std::optional<std::vector<std::string>> rootLibraries; // replaces the root's build.libraries (sn build --libs)
    bool all = false;    // every library, whatever the manifests say (sn build --all-libs)
    bool strict = false; // treat everything as if the root manifest were --!strict
};
```

### `LibrarySelection`

```cpp
struct LibrarySelection {
    std::vector<std::string> libraries; // sorted, no duplicates
    bool all = false;                   // libraries == every known library
    std::vector<std::string> warnings;  // for the user; never fatal
    std::string hint;                   // what to tell someone who requires an unselected library
};
```

### `selectLibraries`

```cpp
LibrarySelection selectLibraries(const Project& root,
                                 const std::vector<InstalledProject>& dependencies,
                                 const LibraryOptions& options = {});
```

Throws `BuildError` listing every problem at once.

```cpp
Project project = Project::find(".");
auto deps = openDependencies(project);
LibrarySelection selection = selectLibraries(project, deps);

for (const auto& warning : selection.warnings)
    std::cerr << "warning: " << warning << '\n';

if (!selection.all)
    loader.restrictLibraries(selection.libraries, selection.hint);
```
