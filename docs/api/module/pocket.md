# @sonata/pocket

Read-only files that travel with the program: whatever the package lists in
[`build.assets`](../../guide/manifest.md#buildassets).

```luau
local pocket = require("@sonata/pocket")

local config = pocket.read("assets/config.json")
```

Under `sn run` the files are read from disk; in a program made by `sn build` they are packed
inside the executable. Either way, **only the files listed in `build.assets` are visible**, so
a program can't come to depend on a file that won't be packed.

A built program reads an asset from its executable only when a script asks for it, so large
assets cost nothing until they're used. To use one that's too big to hold as a string (more
than 1 GiB), or that you'd rather not, read it in pieces with [`pocket.open`](#pocketopen) or
write it out with [`pocket.copy`](#pocketcopy).

Paths are relative to the root of the package the calling script belongs to, use `/`, and may
not leave the package: `"assets/logo.png"` and `"./config.json"` are fine, `"../x"` and
absolute paths are not. Every package (the project and each dependency) sees only its own
assets, so a dependency's `assets/x` never collides with the project's.

## pocket.read

```luau
pocket.read(path: string): string
```

The contents of an asset. Raises an error if there is no such asset, or if it's larger than a
string can hold (1 GiB); [`pocket.open`](#pocketopen) reads those.

## pocket.tryRead

```luau
pocket.tryRead(path: string): string?
```

The contents of an asset, or `nil` if there is no such asset.

## pocket.exists

```luau
pocket.exists(path: string): boolean
```

## pocket.size

```luau
pocket.size(path: string): number
```

An asset's size in bytes, without reading it. Raises an error if there is no such asset.

## pocket.open

```luau
pocket.open(path: string): Reader
```

Opens an asset to read it a piece at a time. Raises an error if there is no such asset. The
reader fits [`@sonata/stream`](stream.md), so it can be piped, split into lines or collected:

```luau
local stream = require("@sonata/stream")

for line in stream.lines(pocket.open("data/words.txt")) do
    print(line)
end
```

### Reader methods

| Method | Description |
|---|---|
| `reader:read(max: number?): string?` | The next piece, at most `max` bytes (default 64 KiB), or `nil` at the end. |
| `reader:close()` | Stops reading. Closing twice is fine; reading after it raises. |

In a built program the asset's checksum is checked as its last piece is read, so damage to the
executable raises there at the latest.

## pocket.copy

```luau
pocket.copy(path: string, destination: string, overwrite: boolean?)
```

Writes an asset to a file, a piece at a time. `overwrite` defaults to `true`; with `false`, an
existing `destination` is an error. The parent folder must exist.

If the asset was executable when it was packed (or, under `sn run`, is executable on disk), the
copy is too. That is how a program ships a helper program:

```luau
local fs = require("@sonata/fs")
local process = require("@sonata/process")

local helper = fs.tempDir() .. "/helper"
pocket.copy("bin/helper", helper)
print(process.exec(helper, { "--version" }).stdout)
```

The file is written beside `destination` and renamed into place, so a failure never leaves half
of it there, and a program already running from an older copy keeps its file. Windows has no
executable bit, so nothing packed there is marked executable: a program built on Windows for
another platform should [`fs.chmod`](fs.md#fschmod) its copy.

## pocket.list

```luau
pocket.list(folder: string?): { string }
```

Every asset of the package, sorted, or only those under `folder`.

```luau
for _, file in pocket.list("assets/templates") do
    print(file) --> "assets/templates/page.html", ...
end
```

## pocket.bundled

```luau
pocket.bundled: boolean
```

`true` inside a program made by `sn build` (the assets come from the executable), `false` under
`sn run`.

## Example

```luau
-- .sonata/project.luau
return {
    name = "greeter",
    build = { assets = { "templates" } },
}
```

```luau
-- main.luau
local pocket = require("@sonata/pocket")
local template = pocket.read("templates/greeting.txt")
print((template:gsub("{name}", args[1] or "world")))
```
