# CLI reference

```
sn <command> [arguments]
```

| Command | Description |
|---|---|
| [`sn init`](#sn-init) | Create a new Sonata project. |
| [`sn run`](#sn-run) | Run a project without compiling it. |
| [`sn build`](#sn-build) | Compile a project into a standalone executable. |
| [`sn test`](#sn-test) | Run the project's tests. |
| [`sn doctor`](#sn-doctor) | Find problems with your installation and project. |
| [`sn libs`](#sn-libs) | List the built-in libraries. |
| [`sn pkg`](#sn-pkg) | Manage packages: `add`, `remove`, `update`, `status`. |

Global options:

| Option | Description |
|---|---|
| `-h`, `--help` | Show the list of commands. After a command (`sn build --help`, `sn pkg add -h`), show that command's help. |
| `-v`, `--version` | Print `sonata <version>`. Add `--verbose` for the commit, build type, platform, compiler and Luau version. |
| `--color <when>` | `auto`, `always` or `never`. Works anywhere on the command line. |

Every command exits with status `0` on success, `1` on failure, and `2` when the command line
itself was wrong. An unknown command or option suggests the closest match
(`did you mean 'run'?`). `sn help <command>` is the same as `sn <command> --help`.

Help is handled for every command before it runs: `-h` or `--help` anywhere in the arguments
(before a bare `--`) prints help instead of running.

## `sn init` {#sn-init}

```
sn init [path] [options]
```

Creates a project in `path` (default: the current directory), creating the folder if needed:
`.sonata/project.luau`, a `main.luau`, and a `.gitignore`. An existing `main.luau` or `.gitignore`
is left alone.

With `--lsp`, also sets up the [Luau Language Server](editors.md). If there's already a project,
that's all it does, and the manifest and your code aren't touched. Without a `path`, that includes
a project above the current folder, so it works from anywhere inside one.

| Option | Description |
|---|---|
| `--name <name>` | Project name (default: the folder's name). |
| `--force`, `-f` | Write a new manifest over an existing one. Without it or `--lsp`, `sn init` refuses to touch an existing project. |
| `--lsp` | Set up the [Luau Language Server](editors.md), in a new project or an existing one. |
| `--no-vscode` | With `--lsp`: don't write `.vscode`, for other editors. |

```sh
sn init
sn init my-app
sn init --name weather
sn init --lsp
```

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
| `--install`, `-i` | Fetch missing dependencies before running. |
| `--verbose`, `-v` | Print the project, entry and libraries in use, and any warnings about them (on stderr). |

Running a project whose declared dependencies aren't installed is an error unless `--install` is
given. Built-in libraries are restricted to the project's
[`build.libraries`](manifest.md#buildlibraries), exactly as in a built program. An entry that is
a [test file](testing.md) follows the [rules of `sn test`](testing.md#libraries-in-tests) instead.

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
| `--libs <a,b,...>`, `-l` | Built-in libraries the program may use, instead of `build.libraries`. |
| `--all-libs` | Allow every built-in library. Can't be combined with `--libs`. |
| `--optimize <0-2>`, `-O` | Luau optimization level (default `1`). |
| `--debug-level <0-2>`, `-g` | Luau debug info: `0` none, `1` line numbers (default), `2` full. |
| `--no-compress` | Don't compress the packed program. `--compress` turns it back on. |
| `--strict` | Treat the project as `--!strict` for this build. |
| `--entry <file>`, `-e` | Start at `<file>` instead of the manifest's entrypoint. Must be a `.luau` file inside the project. |
| `--target <platform>`, `-t` | Build for another platform, like `linux-x64`. Needs [its runtime](building.md#building-for-another-platform) installed. |
| `--runtime <file>` | Use this `sn` executable as the runtime. |
| `--install`, `-i` | Fetch missing dependencies first. |

Options with a value accept both `--name value` and `--name=value`.

```sh
sn build
sn build -o bin/app
sn build --libs fs,path,term
sn build -t windows-x64 -O 2 -g 0
```

## `sn test` {#sn-test}

```
sn test [path] [options]
```

Runs every file named `*.test.luau` in the project containing `path` (default `.`), each as a
program of its own, and reports the cases [`@sonata/test`](../api/module/test.md) ran in them.
If `path` is a test file or a folder inside the project, only those test files run. Test files
may require any built-in library; the rest of the project still gets only `build.libraries`. See
[Testing](testing.md).

| Option | Description |
|---|---|
| `--filter <text>`, `-f` | Run only the cases whose name contains `<text>`. Can be repeated: a case runs if it matches any. |
| `--verbose`, `-v` | List every case, not only the failures. |
| `--install`, `-i` | Fetch missing dependencies first. |

Results go to stdout. The exit status is `1` if a case failed, a file failed outside any case,
there are no test files, or no case matched `--filter`.

```sh
sn test
sn test tests/parser.test.luau
sn test -f slug
```

## `sn doctor` {#sn-doctor}

```
sn doctor [path] [options]
```

Checks your installation, your machine and, inside a project, the project. See
[Checking your setup](doctor.md).

| Option | Description |
|---|---|
| `--fix` | Apply the fixes that are safe to make without asking. |
| `--only <area>` | Check one area: `installation`, `environment` or `project`. |
| `--strict` | Exit with an error on warnings too. |
| `--json` | Print the results as JSON. |

## `sn libs` {#sn-libs}

```
sn libs [name] [options]
```

Lists the built-in libraries, or shows one.

| Option | Description |
|---|---|
| `--types` | Print the library's Luau type definitions. Needs a name. |
| `--json` | Print the list as JSON. |

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

### `sn pkg add` {#sn-pkg-add}

```
sn pkg add [path] [deps] [options]
```

Adds the packages from the given specs (`url` or `url#ref`), with their dependencies, and
records them in the manifest. `deps` can be left out with `--install` or `--read`.

| Option | Description |
|---|---|
| `--read <file>`, `-r` | Read a Luau table from `<file>` and add every dependency in it. A member is a URL string (its key, if any, is the name) or a table with `url` and optional `name` and `ref`. Can be given more than once. |
| `--noreplace` | Leave dependencies that are already installed untouched, including dependencies of dependencies. |
| `--install`, `-i` | Install every dependency listed in the manifest. `deps` given as well are added alongside them. |

```sh
sn pkg add github.com/user/repo
sn pkg add https://github.com/user/repo#v1.2.0
sn pkg add ./my_project github.com/user/repo --noreplace
sn pkg add . github.com/user/repo github.com/user/other
sn pkg add --read deps.luau
sn pkg add -i
```

The command exits with status 1 if any of them failed. The others are still installed.

### `sn pkg remove` {#sn-pkg-remove}

```
sn pkg remove [path] <names> [options]
```

Removes the named dependencies from the manifest and deletes them, along with dependencies
that nothing else uses. `'*'` removes every package (quote it so the shell doesn't expand it).

| Option | Description |
|---|---|
| `--nodep` | Only remove the named dependencies, not the dependencies they brought in. |
| `--nomanifest` | Leave the manifest alone and only delete the dependency folders. |

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
| `--lua` | Print the data as a Luau table, starting with `return `. |
| `--nodep` | Only list the project's own dependencies. |

```sh
sn pkg status
sn pkg status ./my_project --nodep
sn pkg status --lua
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
| `SONATA_HOME` | Sonata's home folder; see [Building executables](building.md#environment-variables). |
| `SSL_CERT_FILE`, `SSL_CERT_DIR` | Where to find root certificates, instead of the usual places. |
