# Building executables

`sn build` turns a project into a single executable that runs without Sonata installed.

```console
$ sn build
Building weather 1.2.0 for linux-x64
  ✓ Selected libraries all
  ✓ Compiled 12 modules
  ✓ Wrote the executable from this sn 9 ms
✓ Built dist/weather (3.8 MiB)
```

## What happens

1. **Settings.** The [`build` table](manifest.md#build) of the manifest is read, and command-line
   options override it for this build.
2. **Libraries.** The built-in libraries the program may use are worked out from
   `build.libraries` of the project and of every installed dependency.
3. **Compile.** Every `.luau` file of the project and of each dependency is compiled to
   bytecode. Every literal `require("@sonata/x")` is checked against the selected libraries.
   All compile errors and unselected libraries are reported together.
4. **Assets.** The files listed in `build.assets` of every package are collected. They are
   copied into the executable a piece at a time when it's written, so no size limit applies.
5. **Runtime.** The `sn` executable to start from is picked (see [Runtimes](#runtimes)). Nothing
   is compiled: this step only finds a file.
6. **Write.** The compiled program is appended to the runtime, producing one executable.

The built program behaves exactly like `sn run`: same module system, same globals, same
libraries. Inside it, [`sonata.bundled`](../api/module/globals.md) is `true` and
`sonata.project.root` is the folder that holds the executable.

## Options

| Option | Manifest field | Description |
|---|---|---|
| `--output <file>`, `-o` | `build.output` | Where to write the program. Default: `dist/<name>`. On the command line the path is relative to the current directory; in the manifest, to the project root. `.exe` is added on Windows. |
| `--libs <a,b,...>`, `-l` | `build.libraries` | The built-in libraries the program may use, replacing the root manifest's list. |
| `--all-libs` | | Allow every built-in library, whatever the manifests say. Can't be combined with `--libs`. |
| `--optimize <0-2>`, `-O` | `build.optimize` | Luau optimization level (default `1`). |
| `--debug-level <0-2>`, `-g` | `build.debug` | Luau debug info: `0` none, `1` line numbers (default), `2` full. |
| `--no-compress` / `--compress` | `build.compress` | Don't compress the packed program / do (the default). |
| `--strict` | `--!strict` | Treat the project as `--!strict` for this build. |
| `--entry <file>`, `-e` | `entrypoint` | Start at another `.luau` file of the project. |
| `--target <platform>`, `-t` | | Build for another platform, like `linux-x64`. See [Runtimes](#runtimes). |
| `--runtime <file>` | | Use this `sn` executable as the runtime. |
| `--install`, `-i` | | Fetch missing dependencies first. |

Options take their value either as `--output dist/app` or `--output=dist/app`.

```sh
sn build -o bin/app
sn build --libs fs,path,term
sn build -t windows-x64 -O 2 -g 0
```

## Choosing libraries

By default a program may use every built-in library. Declaring the ones you use catches mistakes
early:

```luau
build = {
    libraries = { "fs", "path", "term" },
},
```

With this list:

- `sn run` refuses `require("@sonata/net")` with
  `built-in library '@sonata/net' is not enabled for this program (add it to build.libraries in ...)`.
- `sn build` reports every file and line that requires an unlisted library.
- A built program refuses the others in the same way, even through a computed require.

Every library is always in the executable: the list decides what a program may use, not what it
contains, so changing it never slows a build down.

Only literal requires (`require("@sonata/fs")`) are checked at build time. A computed require
still fails at runtime if the library isn't selected.

The [manifest page](manifest.md#buildlibraries) explains how dependencies' lists combine, and
[`--!strict`](manifest.md#strict) makes the lists mandatory.

## Runtimes

The runtime is the part of the executable that runs your program. Sonata has no separate runtime:
`sn` is one. A built program is a copy of the `sn` executable with your compiled program attached,
and when it starts, it finds your program and runs that instead of the command line.

This means `sn build`:

- needs no compiler, CMake or source code;
- takes milliseconds, whatever libraries you use;
- makes programs with no dependencies, because `sn` has none. There's no separate standalone
  mode: every program is standalone.

`sn build` picks the file to start from like this:

1. With `--runtime <file>`, that file. It has to be an `sn` of the same version.
2. For another platform (`--target`), the installed runtime for that platform.
3. Otherwise, the `sn` that's running.

### Building for another platform

Building for another platform is the same file copy, starting from that platform's `sn`:

```sh
sn build --target windows-x64
```

That file has to be in `$SONATA_HOME/runtimes/<version>/<target>/`, as `sn` (or `sn.exe`). It's
`bin/sn` from the platform's [release archive](installation.md#from-a-release), and it has to
match your `sn` version exactly. [`sn doctor`](doctor.md) checks the ones you have.

The targets are `linux-x64`, `linux-arm64`, `macos-x64`, `macos-arm64`, `windows-x64` and
`windows-arm64`.

## Assets

Files listed in `build.assets` are packed into the executable and read with
[`@sonata/pocket`](../api/module/pocket.md):

```luau
-- project.luau
build = { assets = { "assets", "LICENSE" } },
```

```luau
local pocket = require("@sonata/pocket")
local logo = pocket.read("assets/logo.txt")
```

Under `sn run` the same files are read from disk, and only listed files are visible, so a
program can't come to depend on a file that won't be packed. Each package has its own assets:
a dependency's `assets/x` never collides with yours.

A built program doesn't load its assets when it starts: each is read from the executable when a
script asks for it. Large ones can be read in pieces with
[`pocket.open`](../api/module/pocket.md#pocketopen) or written to a file with
[`pocket.copy`](../api/module/pocket.md#pocketcopy), which keeps the executable bit, so a program
can carry a helper program and run it.

## The executable format

A built program is `sn` with a bundle appended to it:

```
[ sn executable ][ assets ][ payload ][ trailer (32 bytes) ]
```

At startup `sn` reads its own file. If it finds a trailer at the end, it runs the program in the
payload, and the command line never starts. The payload holds the compiled modules, the packages with their dependencies
and entrypoints, the list of allowed libraries, and where each asset is. It is zlib-compressed
unless `--no-compress` is given, and protected by a CRC-32.

Each asset is stored on its own, before the payload, and has its own CRC-32. With compression,
an asset is compressed too unless that wouldn't make it smaller (images and archives usually
are already).

Every `sn` also carries a short stamp with its version and platform, so a runtime for another
platform can be checked without running it.

The C++ side of this is documented in [`sonata::bundle`](../api/source/namespaces/bundle.md).

## Environment variables

| Variable | Used for |
|---|---|
| `SONATA_HOME` | Where runtimes for other platforms are kept. Default `~/.sonata`. |
