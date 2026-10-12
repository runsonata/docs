# Modules and require

Sonata replaces Luau's `require` with its own module system. It works the same under `sn run`
and inside a program made by `sn build`.

## The three kinds of require

```luau
local util = require("./util")             -- a file, relative to this script
local shared = require("../shared/strings")
local json5 = require("@json5")            -- an installed package
local parse = require("@json5/src/parse")  -- a file inside a package
local fs = require("@sonata/fs")           -- a built-in library
```

A require string must start with `./`, `../` or `@`. Anything else (`require("util")`) is an
error, which keeps bare names free for future use.

## Resolving a path

Relative paths start from the **folder of the script that calls `require`**. A path `P`
resolves to:

1. `P.luau`, or
2. `P/init.luau`, if `P` is a folder.

If both exist, the require fails as ambiguous. Leave the `.luau` extension out:
`require("./util")`, not `require("./util.luau")`.

A folder `lib/` with an `init.luau` can be required as `require("./lib")`. Inside
`lib/init.luau`, `./helper` means `lib/helper.luau`, since relative paths always start from the
folder of the requiring file.

If the folder is a **package** (it has a `.sonata/project.luau`) whose manifest names an
`entrypoint`, requiring the folder loads that file instead of `init.luau`.

A path may not climb above the root of the file system (or, in a built program, above the
project).

## Packages: `@name`

`@name` refers to an installed dependency. Under `sn run` and in built programs, the name is
looked up in this order:

1. The project's installed dependencies (everything in the root project's `.sonata/deps`).
2. The dependencies declared in the manifest of the package that contains the requiring
   file. This is how a dependency can require the packages it lists itself.

`require("@name")` loads the package's entrypoint (or its `init.luau`), and
`require("@name/some/file")` loads a file inside it.

All packages are installed flat into the root project's `.sonata/deps`, so `@name` means the
same folder no matter who asks. See [Packages](packages.md).

## Built-in libraries: `@sonata/name`

The `@sonata` alias is reserved for Sonata's built-in libraries, which are compiled into
Sonata. They need no files on disk and no entry in `dependencies`:

```luau
local path = require("@sonata/path")
```

The value is a read-only table. Requiring a library that doesn't exist fails with the list of
available ones, and requiring one that isn't in the project's
[`build.libraries`](manifest.md#buildlibraries) fails with a hint to add it.

See the [module API reference](../api/module/index.md) for the full list.

## Module rules

- **A module must return exactly one non-`nil` value.** Usually a table or a function.
- **A module runs once.** The value it returns is cached, and every later `require` of the
  same file returns the same value.
- **Cycles are errors.** If `a` requires `b` and `b` requires `a`, the second require fails with
  a `cyclic require` message showing the chain.
- **Every module runs on its own thread, in a sandbox.** The globals are read-only, so a module
  can't change them for other modules. Share state through the values modules return.

## Globals

Besides the standard Luau libraries (`string`, `table`, `math`, `coroutine`, `buffer`, `utf8`,
`os`, `debug`, `bit32`, `vector`, `print`, ...), every script sees the globals Sonata adds:

| Global | Description |
|---|---|
| `require` | The module loader described on this page. |
| `args` | The program's arguments, as an array of strings. |
| `sonata` | Information about the running program: Sonata's version, the platform, the project. |

See [Globals](../api/module/globals.md).
