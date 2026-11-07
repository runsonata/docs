# Checking your setup

`sn doctor` finds what's wrong with your installation, your machine and your project, and says
how to fix it.

```console
$ sn doctor
♪ Sonata 2.0.0
  All-in-one Luau toolkit

Installation
  ✓ sn 2.0.0 for linux-x64 (release build)
  ! 'sn' on your PATH is a different executable: /usr/local/bin/sn
    that one is Sonata 1.0.3
    → remove the one you don't want, or reorder your PATH
  ✓ sn build works: built a program and ran it
  ...

Project
  ✓ weather 1.2.0 at .
  ! The manifest has a key Sonata doesn't use: build.outptu
    → did you mean 'build.output'?
  ✗ src/main.luau:3: there is no built-in library 'jsn'
    → did you mean '@sonata/json'?

1 error · 2 warnings
```

It exits with status `1` if there are errors, so it works in scripts and CI.

## What it checks

**Installation**

- `sn` can find itself, and isn't damaged.
- `sn` on your `PATH` is this one, and no other copy is hiding it.
- Sonata's home folder exists and can be written to.
- No files are left over from older versions.
- Runtimes for other platforms match this version.
- The VM runs code, and every built-in library loads.
- Root certificates can be found, so HTTPS can check who it's talking to.
- `sn build` really works here: it builds a small program, runs it, and reads its output. This
  catches what looking at files can't, like a temp folder that doesn't allow running programs.

**Environment**

- The terminal's size, and whether colors and Unicode are on.
- The temp folder can be written to.
- Git is installed, if the project has dependencies.
- No environment variables from older versions are set.
- There's enough disk space.

**Project**, when run inside one:

- The manifest can be read, and has no unknown keys. Typos get a suggestion.
- The entrypoint exists, and every source file compiles.
- Every literal `require` resolves: built-in libraries exist and are in `build.libraries`,
  relative paths lead to a file, and `@name` is a declared dependency.
- Dependencies are installed and valid, and there's a lock file.
- Everything in `build.assets` exists.
- `.gitignore` covers generated files.

## Options

| Option | Description |
|---|---|
| `--fix` | Apply the fixes that are safe to make without asking. |
| `--only <area>` | Check one area: `installation`, `environment` or `project`. |
| `--strict` | Exit with an error on warnings too. |
| `--json` | Print the results as JSON. |

```sh
sn doctor
sn doctor --fix
sn doctor ./my-app --only project
sn doctor --json
```

`--fix` creates a missing home folder, adds missing lines to `.gitignore`, and removes caches
left behind by older versions. It only ever makes changes like these, and never touches your
code.
