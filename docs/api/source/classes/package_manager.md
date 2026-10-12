# <code><a href="../../namespaces/sonata">sonata</a>::PackageManager</code> (Class)

Installs, updates and removes a project's dependencies. This is what [`sn pkg`](../../../guide/packages.md)
uses.

`#include <sonata/core/package.hpp>`

```cpp
sonata::Project project = sonata::Project::find(".");
sonata::PackageManager packages(project);
packages.setProgressCallback([](const std::string& line) { std::cerr << line << '\n'; });

for (const auto& pkg : packages.install())
    std::cout << pkg.dependency.name << " @ " << pkg.commit << '\n';
```

## How it works

Dependencies are Git repositories that are themselves Sonata projects. Everything is installed
flat into the **root** project's `.sonata/deps`, dependencies of dependencies included. If two
packages ask for the same name from different sources, the root manifest wins; otherwise it is
an error. Everything inside `.sonata/deps` is owned by the package manager.

To install a package, it:

1. clones it into `.sonata/deps/.staging/<random>`, trying each [`GitBackend`](#gitbackend) in
   order (the `git` executable first, then libgit2 if compiled in);
2. validates it with `Project::open()`: no valid project, no install;
3. drops the `.git` folder and swaps it into `.sonata/deps/<name>`;
4. repeats for whatever the new package depends on.

A failed install never leaves a half-written package behind: the previous version stays in
place.

The lock file (`.sonata/lock.luau`) lets `install` reproduce exactly what was installed before:
if `deps/<name>` is missing but the lock entry still matches the manifest, the locked commit is
fetched rather than whatever the branch points at now. Only `update` moves things forward.

!!! warning

    Not thread-safe. Use one `PackageManager` per project, from one thread.

## Construction

```cpp
explicit PackageManager(Project& project);
PackageManager(Project& project, std::vector<std::unique_ptr<GitBackend>> backends);
```

`project` must outlive the manager; `add` and `remove` edit and save its manifest. The first
constructor uses [`defaultGitBackends()`](#git-backends). Not copyable.

### `setProgressCallback`

```cpp
using ProgressCallback = std::function<void(const std::string&)>;
void setProgressCallback(ProgressCallback callback);
```

Receives human-readable status lines (`"fetching foo ..."`). Optional.

## Methods

### `install`

```cpp
std::vector<InstalledPackage> install();
```

Makes sure every dependency in the manifest (and theirs, recursively) is present in
`.sonata/deps`. Anything already installed and still matching the manifest is left alone.
Returns the whole resolved set in install order.

### `update`

```cpp
std::vector<InstalledPackage> update();
std::vector<InstalledPackage> update(const std::string& name);
```

Re-fetches everything (or one package) from its ref, ignoring the lock file. The second form
throws `PackageError` if `name` isn't a dependency.

### `add`

```cpp
InstalledPackage add(Dependency dependency);
```

Adds (or replaces) a dependency in the manifest, saves it and installs it. If installing fails,
the manifest is put back as it was.

### `remove`

```cpp
std::vector<std::string> remove(const std::string& name);
```

Removes a dependency from the manifest, saves it, then prunes. Returns the names of every
package folder that was deleted: the package itself plus anything only it needed.

### `prune`

```cpp
std::vector<std::string> prune();
```

Deletes every folder in `.sonata/deps` that nothing depends on any more.

### `installed` / `isInstalled`

```cpp
std::vector<InstalledPackage> installed() const;
bool isInstalled(const std::string& name) const;
```

Everything currently in `.sonata/deps`, sorted by name.

### `registerAliases`

```cpp
void registerAliases(luau::ModuleLoader& loader) const;
```

Registers an `@name` alias on the loader for every installed package, so
`require("@name/...")` finds `.sonata/deps/<name>/...`. Call it before
`ModuleLoader::install()`/`run()`. This is for `sn run`; `sn build` maps the same folders into
its virtual root instead.

### `lockFile`

```cpp
std::filesystem::path lockFile() const;
```

`<root>/.sonata/lock.luau`.

### `validate`

```cpp
static void validate(const Dependency& dependency);
```

Checks a dependency declaration (see [`Project::Dependency`](project.md#dependency)). Throws
`PackageError`.

## `InstalledPackage`

```cpp
struct InstalledPackage {
    Project::Dependency dependency; // url/ref may be empty if unknown (not in the lock file)
    std::filesystem::path path;     // .sonata/deps/<name>
    std::string commit;             // exact commit; empty if unknown
    bool fresh = false;             // true if fetched by this call
};
```

## `PackageError`

```cpp
class PackageError : public std::runtime_error;
```

Thrown by the package manager for every failure: a bad declaration, a clone that fails, a
dependency conflict, an invalid package.

## `GitBackend`

```cpp
class GitBackend {
public:
    virtual ~GitBackend() = default;
    virtual std::string_view name() const noexcept = 0;
    virtual bool available() const = 0;
    virtual std::string clone(const std::string& url,
                              const std::filesystem::path& destination,
                              const std::string& ref) const = 0;
};
```

One way of getting a repository onto disk. `PackageManager` tries its backends in order until
one works.

| Method | Description |
|---|---|
| `name()` | A name for messages. |
| `available()` | `false` if the backend can't be used at all (e.g. no `git` executable). |
| `clone(url, destination, ref)` | Clones `url` into `destination` (which must not exist yet) and checks out `ref` (a branch, tag or commit; empty = the remote's default branch). Returns the full hash of the commit checked out. Throws `PackageError`; the caller removes any partial result. |

### Git backends

```cpp
std::unique_ptr<GitBackend> makeCliGitBackend();
std::unique_ptr<GitBackend> makeLibGit2Backend();
std::vector<std::unique_ptr<GitBackend>> defaultGitBackends();
```

| Function | Returns |
|---|---|
| `makeCliGitBackend()` | A backend that runs the `git` executable found on `PATH` (with `GIT_TERMINAL_PROMPT=0`). |
| `makeLibGit2Backend()` | A libgit2 backend, or `nullptr` unless Sonata was compiled with `SONATA_USE_LIBGIT2`. |
| `defaultGitBackends()` | `{ CLI git, libgit2 (if compiled in) }`. |

A custom backend is handy in tests:

```cpp
struct FakeGit : sonata::GitBackend {
    std::string_view name() const noexcept override { return "fake"; }
    bool available() const override { return true; }
    std::string clone(const std::string& url, const std::filesystem::path& dest,
                      const std::string& ref) const override {
        copyFixture(url, dest);
        return "0123456789abcdef0123456789abcdef01234567";
    }
};

std::vector<std::unique_ptr<sonata::GitBackend>> backends;
backends.push_back(std::make_unique<FakeGit>());
sonata::PackageManager packages(project, std::move(backends));
```
