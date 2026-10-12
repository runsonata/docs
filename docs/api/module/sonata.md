# @sonata/sonata

Access to Sonata's own internals from Luau: build information, projects and the package
manager. Useful for tooling, such as scripts that inspect or set up projects.

```luau
local sonata = require("@sonata/sonata")

print(sonata.info.version, sonata.info.platform)
local project = sonata.findProject()
print(project.manifest.name, #project.manifest.dependencies)
```

!!! note

    This library is not the [`sonata` global](globals.md#sonata). The global describes the
    running program; this library describes the Sonata installation and lets you work with any
    project on disk.

**Errors:** failures raise a Luau error carrying the underlying message (use `pcall`).
Unspecified strings are `""` rather than `nil`, and paths use `/`. Relative paths are relative
to the current directory; where a project path is optional, the default is `"."`.

## sonata.info

```luau
sonata.info: {
    name: string,          -- "Sonata"
    id: string,            -- "sonata"
    binary: string,        -- "sn"
    tagline: string,       -- "All-in-one Luau toolkit"
    version: string,       -- "0.1.8" or "0.2.0-alpha.1"
    semver: { major: number, minor: number, patch: number, pre: string },
    gitHash: string,       -- short commit hash, "" if unknown
    luauVersion: string,   -- "" if unknown
    buildType: string,     -- "release", "debug", ...
    debug: boolean,
    platform: string,      -- "linux-x64", "macos-arm64", "windows-x64", ...
    compiler: string,      -- "gcc 13.2.0", "clang 17.0.6", "msvc 1939"
}
```

Read-only information about the Sonata build running the program.

## Types

```luau
type Dependency = {
    name: string,
    url: string,
    ref: string?, -- optional when passed in; "" when returned without one
}

type Package = Dependency & {
    path: string,    -- where it is installed (.sonata/deps/<name>)
    commit: string,  -- the exact commit, "" if unknown
    fresh: boolean,  -- true if this call fetched it
}

type Project = {
    root: string,
    entrypoint: string,       -- absolute path of the entry script
    sonataDir: string,        -- <root>/.sonata
    projectFile: string,      -- <root>/.sonata/project.luau
    dependenciesDir: string,  -- <root>/.sonata/deps
    hasDependenciesDirectory: boolean,
    sources: { string },      -- every .luau file of the project (outside .sonata)
    manifest: {
        name: string,
        version: string,
        description: string,
        entrypoint: string,   -- as written in the manifest
        authors: { string },
        dependencies: { Dependency },
    },
}
```

Projects are plain snapshots: nothing stays open, and changing the table changes nothing on
disk.

## Projects

### sonata.openProject

```luau
sonata.openProject(dir: string?): Project
```

Opens the project whose root is `dir`. Raises if `dir` isn't a valid project root.

### sonata.findProject

```luau
sonata.findProject(start: string?): Project
```

Finds the project containing `start` (a folder or a file), searching its parent folders.

### sonata.validateProject

```luau
sonata.validateProject(dir: string?): (boolean, string?)
```

Whether `dir` is a valid project root, and if not, why.

### sonata.validateDependency

```luau
sonata.validateDependency(dep: Dependency): (boolean, string?)
```

Whether a dependency declaration follows the [rules](../../guide/manifest.md#dependencies), and
if not, the first rule it breaks.

## Packages

These run the same package manager as [`sn pkg`](../../guide/packages.md). The project is always
the optional **last** argument, found like `findProject` does. Each call also returns the
package manager's progress messages as a second value. They block while Git runs.

### sonata.install

```luau
sonata.install(project: string?): ({ Package }, { string })
```

Makes sure every dependency in the manifest (and theirs) is installed. Returns the whole set in
install order.

### sonata.update

```luau
sonata.update(name: string?, project: string?): ({ Package }, { string })
```

Re-fetches every package from its ref, ignoring the lock file, or only `name`.

### sonata.add

```luau
sonata.add(dep: Dependency, project: string?): (Package, { string })
```

Adds (or replaces) a dependency in the manifest and installs it. If installing fails, the
manifest is restored.

### sonata.remove

```luau
sonata.remove(name: string, project: string?): ({ string }, { string })
```

Removes a dependency from the manifest and deletes every folder nothing needs any more.
Returns the names of the deleted folders.

### sonata.prune

```luau
sonata.prune(project: string?): ({ string }, { string })
```

Deletes every installed package that nothing depends on. Returns the deleted names.

### sonata.installed

```luau
sonata.installed(project: string?): ({ Package }, { string })
```

Everything currently in `.sonata/deps`, sorted by name.

```luau
local packages, log = sonata.install()
for _, line in log do
    print(line)
end
for _, pkg in packages do
    print(pkg.name, pkg.commit:sub(1, 10), pkg.fresh and "(new)" or "")
end
```
