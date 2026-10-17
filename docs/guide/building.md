# Building executables

`sn build` turns a project into a single executable that runs without Sonata installed.

```console
$ sn build
built /home/me/weather/dist/weather (2.1 MiB)
```

## What happens

1. **Settings.** The [`build` table](manifest.md#build) of the manifest is read, and command-line
   options override it for this build.
2. **Libraries.** The built-in libraries the program may use are worked out from
   `build.libraries` of the project and of every installed dependency.
3. **Compile.** Every `.luau` file of the project and of each dependency is compiled to
   bytecode. Every literal `require("@sonata/x")` is checked against the selected libraries.
   All compile errors and unselected libraries are reported together.
4. **Assets.** The files listed in `build.assets` of every package are read.
5. **Runtime.** A copy of the Sonata runtime (`snrt`) is chosen or built (see
   [Runtimes](#runtimes)).
6. **Write.** The compiled program is appended to the runtime, producing one executable.

The built program behaves exactly like `sn run`: same module system, same globals, same
libraries. Inside it, [`sonata.bundled`](../api/module/globals.md) is `true` and
`sonata.project.root` is the folder that holds the executable.

## Options

| Option | Manifest field | Description |
|---|---|---|
| `--output <file>`, `-o` | `build.output` | Where to write the program. Default: `dist/<name>`. On the command line the path is relative to the current directory; in the manifest, to the project root. `.exe` is added on Windows. |
| `--libs <a,b,...>`, `-l` | `build.libraries` | The built-in libraries the project uses, replacing the root manifest's list. |
| `--all-libs` | | Include every built-in library, whatever the manifests say. |
| `--optimize <0-2>`, `-O` | `build.optimize` | Luau optimization level (default `1`). |
| `--debug-level <0-2>`, `-g` | `build.debug` | Luau debug info: `0` none, `1` line numbers (default), `2` full. |
| `--no-compress` / `--compress` | `build.compress` | Don't compress the packed program / do (the default). |
| `--standalone` | `build.standalone` | No shared-library dependencies at all. Requires a runtime built from source. |
| `--strict` | `--!strict` | Treat the project as `--!strict` for this build. |
| `--entry <file>`, `-e` | `entrypoint` | Start at another `.luau` file of the project. |
| `--runtime <file>` | | Use this `snrt` instead of finding or building one. |
| `--install`, `-i` | | Install missing dependencies first. |
| `--verbose`, `-v` | | Show the runtime used, counts of modules, assets and packages, and the runtime's build output. |

Options take their value either as `--output dist/app` or `--output=dist/app`.

```sh
sn build -o bin/app
sn build --libs fs,path,term
sn build --standalone -O 2 -g 0
```

## Choosing libraries

By default a program may use every built-in library. Declaring the ones you use makes the
program smaller and catches mistakes early:

```luau
build = {
    libraries = { "fs", "path", "term" },
},
```

With this list:

- `sn run` refuses `require("@sonata/net")` with
  `built-in library '@sonata/net' is not enabled for this program (add it to build.libraries in ...)`.
- `sn build` reports every file and line that requires an unlisted library, and builds a
  runtime that contains only `fs`, `path` and `term`.

Only literal requires (`require("@sonata/fs")`) are checked at build time. A computed require
still fails at runtime if the library isn't selected.

The [manifest page](manifest.md#buildlibraries) explains how dependencies' lists combine, and
[`--!strict`](manifest.md#strict) makes the lists mandatory.

## Runtimes

The runtime is the part of the executable that runs your program: the Luau VM plus the built-in
libraries. `sn build` picks one like this:

1. With `--runtime <file>`, that file.
2. If every library is selected and `--standalone` isn't set, the **prebuilt runtime** installed
   with `sn`. It is looked for in `$SONATA_RUNTIME`, next to `sn`, in `../libexec/sonata/`, and
   in `../runtime/` (a build tree).
3. Otherwise a **tailored runtime** is built from Sonata's source with CMake, containing only
   the selected libraries. It is cached, so only the first build of a given combination is slow
   (a few minutes).

If a tailored runtime can't be built (no CMake or compiler, for example), `sn build` falls back
to the prebuilt runtime with a warning. The program still can't require the unselected
libraries; it is just larger than it needs to be. `--standalone` never falls back.

### Where the source comes from

A tailored runtime needs Sonata's source code. `sn build` uses, in order:

1. `$SONATA_SOURCE`, which must be a checkout with its submodules;
2. the source tree `sn` itself was built from, if it still exists;
3. a clone of the release tag matching your `sn` version (`v0.1.8`), fetched once into
   `$SONATA_HOME/source/`.

Built runtimes are cached in `$SONATA_HOME/runtimes/`. `SONATA_HOME` defaults to `~/.sonata`.

### Standalone programs

A normal runtime links OpenSSL, zlib and the C++ runtime statically where static copies exist,
so a built program only needs the operating system's own C library. `--standalone` goes
further and links everything statically (the C runtime too, on Windows).

- It needs CMake, a C++ compiler and static versions of zlib and OpenSSL (if `net` is selected).
- It isn't possible on macOS, which has no static system libraries.
- It can't include `@sonata/image`: ImageMagick, and the libraries it was built with, are
  linked as shared libraries.
- On Linux with glibc, DNS lookups in `@sonata/net` still load glibc's NSS modules at runtime.
  For a program that runs on any Linux, build Sonata with a musl toolchain (Alpine, or
  `musl-gcc`).

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

## The executable format

A built program is the runtime with a bundle appended to it:

```
[ runtime executable ][ payload ][ trailer (32 bytes) ]
```

At startup the runtime reads its own file, finds the trailer at the end, and runs the program
in the payload. The payload holds the compiled modules, the packages with their dependencies
and entrypoints, the assets, and the list of allowed libraries. It is zlib-compressed unless
`--no-compress` is given, and protected by a CRC-32. Running `snrt` on its own, without a
bundle, just prints a short message and exits.

The C++ side of this is documented in [`sonata::bundle`](../api/source/namespaces/bundle.md).

## Environment variables

| Variable | Used for |
|---|---|
| `SONATA_RUNTIME` | Path of the prebuilt runtime, instead of looking next to `sn`. |
| `SONATA_SOURCE` | A Sonata source checkout to build tailored runtimes from. |
| `SONATA_HOME` | Where runtimes and source clones are cached. Default `~/.sonata`. |
