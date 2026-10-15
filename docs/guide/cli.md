# CLI reference

```
sn <command> [arguments]
```

| Command | Description |
|---|---|
| [`sn init`](#sn-init) | Create a new Sonata project. |
| [`sn run`](#sn-run) | Run a project without compiling it. |
| [`sn build`](#sn-build) | Compile a project into a standalone executable. |
| [`sn pkg`](#sn-pkg) | Manage packages: `add`, `remove`, `update`, `status`. |

Global options:

| Option | Description |
|---|---|
| `-h`, `--help` | Show the list of commands. After a command (`sn build --help`, `sn pkg add -h`), show that command's help. |
| `-v`, `--version` | Print `sonata <version>`. Add `--verbose` for the commit, build type, platform, compiler and Luau version. |

Every command exits with status `0` on success and `1` on failure. An unknown command
suggests the closest match (`Did you mean 'run'?`).

Help is handled for every command before it runs: `-h` or `--help` anywhere in the arguments
(before a bare `--`) prints help instead of running.

## `sn init` {#sn-init}

```
sn init [path] [options]
```

Creates a project in `path` (default: the current directory), creating the folder if needed:
`.sonata/project.luau`, `.sonata/deps/` and a `main.luau` that prints `Hello World!`.

If the folder already holds a project (it has a `.sonata/project.luau`), `sn init` asks what to
do:

1. **Initialize anyway**: overwrite `main.luau` and `.sonata/project.luau`.
2. **Clear the folder and initialize**: delete everything in the folder first.
3. **Cancel** (also chosen when stdin is closed, e.g. in a script).

A `main.luau` in a folder that isn't a project yet is overwritten without asking.

| Option | Description |
|---|---|
| `--validate` | Don't create anything. Check that `path` (default: the current directory) is a valid project, and print its root and manifest. Can't be combined with `--lsp` or `--lsp-only`. |
| `--lsp` | Also set up the [Luau Language Server](#sn-init-lsp) for the new project. |
| `--lsp-only` | Only write the Luau Language Server files, in an existing project. `main.luau` and the manifest are left alone, and nothing is asked. |
| `--no-vscode` | With `--lsp` or `--lsp-only`: don't write `.vscode/settings.json`. |

```sh
sn init
sn init my-project --lsp
sn init --lsp-only
sn init --lsp-only --no-vscode
sn init my-project --validate
```

### Luau Language Server {#sn-init-lsp}

`--lsp` and `--lsp-only` set a project up for [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp),
the Luau Language Server, so the editor knows the types of the built-in libraries, the
globals and the installed packages. They write:

| File | Contents |
|---|---|
| `.sonata/types/libs/<name>.luau` | The API of each built-in library, with its documentation, so `require("@sonata/<name>")` is typed. |
| `.sonata/types/globals.d.luau` | The globals Sonata adds: [`args`](../api/module/globals.md#args) and [`sonata`](../api/module/globals.md#sonata). |
| `.luaurc` | Aliases: `sonata` points to `.sonata/types/libs`, and each package in `.sonata/deps` gets one for `require("@<name>")`. |
| `.vscode/settings.json` | Settings for the VS Code extension: `luau-lsp.platform.type` set to `"standard"`, the Rojo sourcemap turned off, and `globals.d.luau` loaded as a definition file. |

`.sonata/types` belongs to Sonata: it's rewritten each time, so don't edit it. Run
`sn init --lsp-only` again after updating Sonata to get the types of the new version.

An existing `.luaurc` or `.vscode/settings.json` is merged into: other settings and aliases are
kept. A file with comments is left alone instead, since rewriting it would drop them;
`sn init` then prints what to add by hand. Other editors need the same settings as the
VS Code ones: the `standard` platform, and `.sonata/types/globals.d.luau` as a definition
file (`--definitions:@sonata=.sonata/types/globals.d.luau`).

The package aliases follow `.sonata/deps`: [`sn pkg add`](#sn-pkg-add),
[`remove`](#sn-pkg-remove), [`update`](#sn-pkg-update) and the `--install` option of
`sn run` and `sn build` update them in projects set up this way.

!!! note
    luau-lsp loads a package's `init.luau`, while Sonata loads its manifest's
    [`entrypoint`](manifest.md#entrypoint). For a package whose entrypoint is another file
    (such as the default `main.luau`), the alias points to that file: `require("@name")` is
    typed, but `require("@name/file")` is looked for next to the entrypoint instead of at the
    package root.

## `sn run` {#sn-run}

```
sn run [path] [options] [-- <args>...]
```

Runs the project containing `path` (default `.`; parent folders are searched for
`.sonata/project.luau`), starting at its entrypoint. Arguments after `--` are passed to the
script as [`args`](../api/module/globals.md).

| Option | Description |
|---|---|
| `--entry <file>`, `-e` | Run `<file>` (relative to the project root) instead of the manifest's entrypoint. `--entry=<file>` works too. |
| `--install`, `-i` | Install missing dependencies before running. |
| `--verbose`, `-v` | Print the project, entry, packages and libraries in use, and any warnings about them (on stderr). |

Running a project whose declared dependencies aren't installed is an error unless `--install`
is given. Built-in libraries are restricted to the project's
[`build.libraries`](manifest.md#buildlibraries), exactly as in a built program.

```sh
sn run
sn run ./my-project
sn run --entry tools/seed.luau
sn run -- --port 8080
```

## `sn build` {#sn-build}

```
sn build [path] [options]
```

Compiles the project containing `path` (default `.`) and its dependencies into one standalone
executable. See [Building executables](building.md) for the full picture.

| Option | Description |
|---|---|
| `--output <file>`, `-o` | Where to write the program (default: `build.output`, or `dist/<name>`). |
| `--libs <a,b,...>`, `-l` | Built-in libraries the project uses, instead of `build.libraries`. |
| `--all-libs` | Include every built-in library. Can't be combined with `--libs`. |
| `--optimize <0-2>`, `-O` | Luau optimization level (default `1`). |
| `--debug-level <0-2>`, `-g` | Luau debug info: `0` none, `1` line numbers (default), `2` full. |
| `--no-compress` | Don't compress the packed program. `--compress` turns it back on. |
| `--standalone` | No shared-library dependencies at all (needs a runtime built from source). |
| `--strict` | Treat the project as `--!strict` for this build. |
| `--entry <file>`, `-e` | Start at `<file>` instead of the manifest's entrypoint. Must be a `.luau` file inside the project. |
| `--runtime <file>` | Use this Sonata runtime (`snrt`) instead of finding one. |
| `--install`, `-i` | Install missing dependencies first. |
| `--verbose`, `-v` | Show details, including the runtime's build output. |

Options with a value accept both `--name value` and `--name=value`.

```sh
sn build
sn build -o bin/app
sn build --libs fs,path,term
sn build --standalone -O 2 -g 0
```

## `sn pkg` {#sn-pkg}

```
sn pkg <command> [path] [deps|names] [options]
```

Manages the dependencies of the project at `path`. See [Packages](packages.md) for how they
work.

`path` is optional (default `.`). Because dependency specs and names are also positional, the
first argument is only taken as the path when it clearly is one: it starts with `.`, `/`, `\`
or `~`, or is a Windows drive path like `C:\...`. A bare name or a URL such as
`github.com/user/repo` is never mistaken for a path. A bare `--` ends option parsing.

In a project set up with [`sn init --lsp`](#sn-init-lsp), `add`, `remove` and `update` also
update the package aliases in `.luaurc`.

### `sn pkg add` {#sn-pkg-add}

```
sn pkg add [path] [deps] [options]
```

Adds the packages from the given specs (`url` or `url#ref`), with their dependencies, and
records them in the manifest. `deps` can be left out with `--install` or `--read`.

| Option | Description |
|---|---|
| `--read <file>`, `-r` | Read a Luau table from `<file>` and add every dependency in it. A member is a URL string (its key, if any, is the name) or a table with `url` and optional `name` and `ref`. Can be given more than once. |
| `--noreplace`, `-nr` | Leave dependencies that are already installed untouched, including dependencies of dependencies. |
| `--install`, `-i` | Install every dependency listed in the manifest. `deps` given as well are added alongside them. |

```sh
sn pkg add github.com/user/repo
sn pkg add https://github.com/user/repo#v1.2.0
sn pkg add ./my_project github.com/user/repo -nr
sn pkg add . github.com/user/repo github.com/user/other
sn pkg add --read deps.luau
sn pkg add -i
```

The command prints `<added> out of <total> dependencies successfully installed` and exits with
status 1 if any of them failed.

### `sn pkg remove` {#sn-pkg-remove}

```
sn pkg remove [path] <names> [options]
```

Removes the named dependencies from the manifest and deletes them, along with dependencies
that nothing else uses. `'*'` removes every package (quote it so the shell doesn't expand it).

| Option | Description |
|---|---|
| `--nodep`, `-nd` | Only remove the named dependencies, not the dependencies they brought in. |
| `--nomanifest`, `-nm` | Leave the manifest alone and only delete the dependency folders. |

```sh
sn pkg remove json
sn pkg remove . json util
sn pkg remove ./my_project json --nodep
sn pkg remove json --nomanifest
sn pkg remove '*'
```

### `sn pkg update` {#sn-pkg-update}

```
sn pkg update [path] [names]
```

Re-fetches packages from their refs, ignoring the lock file, and records the new commits. With
no names (or `*`), every package is updated.

```sh
sn pkg update
sn pkg update ./my_project
sn pkg update . json util
```

### `sn pkg status`

```
sn pkg status [path] [options]
```

Lists every dependency with its version, source, lock information, what it depends on and
what uses it, plus its [state](packages.md#inspecting).

| Option | Description |
|---|---|
| `--lua [<bool>]` | Print the data as a Luau table. The boolean (default `true`) says whether to start the output with `return `. |
| `--nodep`, `-nd` | Only list the project's own dependencies. |

```sh
sn pkg status
sn pkg status ./my_project --nodep
sn pkg status --lua
sn pkg status --lua false
```

The `--lua` output has this shape:

```luau
return {
    project = { name = "...", version = "...", root = "...", lockFile = ".sonata/lock.luau", locked = true },
    packages = {
        {
            name = "json5", direct = true, installed = true, state = "ok",
            version = "2.0.0", url = "...", ref = "v2.0.0", path = ".sonata/deps/json5",
            lock = { url = "...", ref = "v2.0.0", commit = "..." },
            dependencies = {}, usedBy = {},
        },
    },
}
```

## Environment variables

| Variable | Effect |
|---|---|
| `NO_COLOR` | Disable colored output. |
| `FORCE_COLOR` | Keep colored output even when it isn't a terminal. |
| `SONATA_RUNTIME`, `SONATA_SOURCE`, `SONATA_HOME` | Used by `sn build`; see [Building executables](building.md#environment-variables). |
