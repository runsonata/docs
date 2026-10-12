# The project manifest

Every Sonata project has a manifest at `.sonata/project.luau`. A folder is a Sonata project
exactly when it contains this file and the entry script the file names.

```luau
--!strict
return {
    name = "weather",
    version = "1.2.0",
    description = "Prints the forecast",
    authors = { "Ada" },
    entrypoint = "src/main.luau",

    dependencies = {
        { name = "json5", url = "https://github.com/acme/json5.git", ref = "v2.0.0" },
        { name = "cli", url = "https://github.com/acme/cli.git" },
    },

    build = {
        output = "bin/weather",
        libraries = { "net", "json", "term" },
        assets = { "assets", "LICENSE" },
        optimize = 2,
        debug = 1,
        compress = true,
        standalone = false,
    },
}
```

## Format

The manifest is a Luau file whose whole body is `return { ... }`. It is parsed, never run, so
it may only contain **literal values**: `nil`, booleans, numbers (optionally with a unary
`-`), strings, and tables of those. Variables, function calls and other operators are
rejected. Comments are fine.

Sonata rewrites the manifest when `sn pkg add` or `sn pkg remove` change the dependencies. The
file is then regenerated: fields Sonata doesn't manage (including `build`) are kept, as is a
`--!strict` line, but other comments and formatting are not.

## Fields

| Field | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | *required* | The project's name. Built programs are named after it by default. |
| `version` | `string` | `"0.0.0"` | The project's version. |
| `description` | `string` | `""` | A short description. |
| `authors` | `{ string }` | `{}` | The project's authors. |
| `entrypoint` | `string` | `"main.luau"` | The script `sn run` and built programs start with, relative to the project root. |
| `dependencies` | `{ Dependency }` | `{}` | Packages this project uses. See [below](#dependencies). |
| `build` | `table` | `{}` | Build settings. See [below](#build). |

### `entrypoint`

The path is relative to the project root and must stay inside it: `"../other/main.luau"` is
an error. The file must exist when the project is opened.

When the project is used as a [package](packages.md), `require("@name")` loads the
entrypoint, so a library package usually points it at its main module (for example
`"src/init.luau"`).

### `dependencies`

An array of tables, one per dependency:

```luau
dependencies = {
    { name = "json5", url = "https://github.com/acme/json5.git", ref = "v2.0.0" },
    { name = "cli",   url = "git@github.com:acme/cli.git" },
},
```

| Key | Rules |
|---|---|
| `name` | Letters, digits and `_` only; must not start with a digit. Scripts require the package as `@name`. Names must be unique. |
| `url` | A Git repository URL, as `git clone` accepts it. Must not be empty, start with `-`, or contain control characters. |
| `ref` | *Optional.* A branch, tag or commit hash. Without it, the remote's default branch is used. Must not start with `-`, contain `..`, a space, a control character or any of `~ ^ : ? * [ \`. |

You rarely edit this by hand: [`sn pkg add`](packages.md) fills it in for you.

### `build`

Settings for [`sn build`](building.md). Every field is optional. The command line can override
each one for a single build.

| Key | Type | Default | Description |
|---|---|---|---|
| `output` | `string` | `"dist/<name>"` | Where to write the program, relative to the project root. `.exe` is added on Windows. |
| `libraries` | `{ string }` | every library | The built-in libraries the project uses, e.g. `{ "fs", "path" }`. See [below](#buildlibraries). |
| `assets` | `{ string }` | `{}` | Files and folders that travel with the program, readable through [`@sonata/pocket`](../api/module/pocket.md). |
| `optimize` | `0`, `1` or `2` | `1` | Luau optimization level. `2` inlines functions and unrolls loops. |
| `debug` | `0`, `1` or `2` | `1` | Luau debug information. `0` none, `1` line numbers for stack traces, `2` full. |
| `compress` | `boolean` | `true` | Compress the program packed into the executable. |
| `standalone` | `boolean` | `false` | Produce an executable with no shared-library dependencies at all. |

#### `build.libraries`

This list is the set of `@sonata/*` libraries the project may use, and it is enforced
everywhere:

- `sn run` refuses to load a library that isn't listed, so the program behaves the same before
  and after it is built.
- `sn build` checks every literal `require("@sonata/...")` in your code against it, and builds
  a smaller runtime containing only those libraries.

Leaving the field out means "every library". Unknown names are an error (with a suggestion if
it looks like a typo).

When dependencies are involved, the allowed set is the union of the root project's list and
the list of every installed dependency. A dependency without a list pulls in every library,
and Sonata prints a warning when the root project has a list of its own.

#### `build.assets`

Each entry is a file or folder relative to the project root (it must not leave the project).
Folders are included recursively, skipping any `.sonata` folder. Under `sn run` the files are
read from disk; `sn build` packs them into the executable. Either way only the listed files are
visible through [`@sonata/pocket`](../api/module/pocket.md).

A dependency's manifest contributes its own `libraries` and `assets`. The other `build`
settings are taken from the root project only.

## `--!strict` {#strict}

A manifest whose first line is `--!strict` makes library declarations mandatory:

- The project itself must have a `build.libraries` list.
- Every dependency must have one too. Without `--!strict`, a dependency missing its list only
  causes a warning.

`sn build --strict` applies the same rules to a single build without editing the manifest.

## Validation errors

Opening a project fails with a message naming the manifest and the field when:

- `.sonata/project.luau` is missing, can't be parsed, or doesn't return a table;
- `name` is missing, or a field has the wrong type;
- the entrypoint is outside the project, missing, or not a regular file;
- a dependency is invalid or two dependencies share a name;
- a `build` field has the wrong type, a level isn't 0, 1 or 2, or an asset path leaves the project.

`sn init --validate` is a quick way to check a manifest.
