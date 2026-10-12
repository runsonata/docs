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

Paths are relative to the root of the package the calling script belongs to, use `/`, and may
not leave the package: `"assets/logo.png"` and `"./config.json"` are fine, `"../x"` and
absolute paths are not. Every package (the project and each dependency) sees only its own
assets, so a dependency's `assets/x` never collides with the project's.

## pocket.read

```luau
pocket.read(path: string): string
```

The contents of an asset. Raises an error if there is no such asset.

## pocket.tryRead

```luau
pocket.tryRead(path: string): string?
```

The contents of an asset, or `nil` if there is no such asset.

## pocket.exists

```luau
pocket.exists(path: string): boolean
```

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
