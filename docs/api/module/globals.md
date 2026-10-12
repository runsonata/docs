# Globals

Every script runs with the standard Luau libraries (`string`, `table`, `math`, `coroutine`,
`buffer`, `utf8`, `os`, `debug`, `bit32`, `vector`, `print`, `pcall`, ...) plus the globals on
this page.

All globals are **read-only**: the environment is sandboxed before the entry script runs, so a
module can't replace or modify a global for others.

## `require`

```luau
require(path: string): any
```

Loads a module and returns the value it returned. Each module runs once; later calls return
the cached value.

| Form | Loads |
|---|---|
| `require("./file")`, `require("../dir/file")` | `file.luau` or `file/init.luau`, relative to the calling script's folder. |
| `require("@name")`, `require("@name/path")` | An installed package (its entrypoint), or a file inside it. |
| `require("@sonata/name")` | A [built-in library](index.md#built-in-libraries). |

Raises an error if the module can't be found or compiled, fails while running, doesn't return
exactly one non-`nil` value, or is part of a require cycle.

See [Modules and require](../../guide/modules.md) for the full rules.

## `args`

```luau
args: { string }
```

The arguments given to the program, as a read-only array.

- Under `sn run`, the arguments after `--`: `sn run -- a b` gives `{ "a", "b" }`.
- In a built program, every argument after the program's name.

The same array is [`process.args`](process.md).

## `sonata`

```luau
sonata: {
    version: string,
    platform: string,
    entry: string,
    bundled: boolean,
    executable: string?,
    project: {
        name: string,
        version: string,
        root: string,
    },
}
```

What the running program knows about itself.

| Field | Description |
|---|---|
| `version` | Sonata's version, e.g. `"0.1.8"`. |
| `platform` | `"<os>-<arch>"`: `"linux-x64"`, `"macos-arm64"`, `"windows-x64"`, ... |
| `entry` | The module path of the entry script. Under `sn run`, an absolute path on disk; in a built program, a virtual path such as `"/main.luau"`. |
| `bundled` | `true` inside a program made by `sn build`, `false` under `sn run`. |
| `executable` | The path of the program's executable. Only set when `bundled` is `true`. |
| `project.name` | The `name` from the manifest. |
| `project.version` | The `version` from the manifest. |
| `project.root` | Under `sn run`, the project folder. In a built program, the folder that contains the executable. |

```luau
if sonata.bundled then
    print(`{sonata.project.name} {sonata.project.version}, running from {sonata.executable}`)
else
    print("running under sn run in", sonata.project.root)
end
```

For Sonata's build details (commit, compiler, Luau version) see
[`@sonata/sonata`](sonata.md#sonatainfo).
