# @sonata/path

Lexical path manipulation. Nothing here touches the disk except `resolve`, which reads the
current directory.

```luau
local path = require("@sonata/path")
```

`path.*` uses the style of the host OS. `path.posix.*` and `path.win32.*` are the same functions
for one fixed style, useful for handling paths from another OS. On the other style's host they
can't know a working directory, so `resolve` leaves relative results relative. `win32`
comparisons are ASCII case-insensitive.

**Errors:** functions raise on bad arguments.

## Constants

| Name | POSIX | Windows |
|---|---|---|
| `path.sep` | `"/"` | `"\\"` |
| `path.delimiter` | `":"` | `";"` |
| `path.style` | `"posix"` | `"win32"` |
| `path.posix`, `path.win32` | The same API with a fixed style. | |

## Building and normalizing

Results never end in a separator, except for roots.

### path.normalize

```luau
path.normalize(p: string): string
```

Removes `.` segments and duplicate separators, and resolves `..`.

```luau
path.normalize("/a/./b//c/..") --> "/a/b"
```

### path.join

```luau
path.join(...: string): string
```

Joins segments and normalizes the result. With no arguments, returns `"."`.

```luau
path.join("a", "b/", "../c") --> "a/c"
```

### path.resolve

```luau
path.resolve(...: string): string
```

Processes the segments from right to left until an absolute path is formed, prepending the
current directory if none is.

```luau
path.resolve("src", "../lib") --> "<cwd>/lib"
path.resolve("/a", "b")       --> "/a/b"
```

### path.relative

```luau
path.relative(from: string, to: string): string
```

The path from `from` to `to`. Returns `"."` for the same path.

```luau
path.relative("/a/b", "/a/c/d") --> "../c/d"
```

### path.isInside

```luau
path.isInside(child: string, parent: string): boolean
```

Whether `child` is `parent` or somewhere below it.

```luau
path.isInside("/a/b/c", "/a/b") --> true
path.isInside("/a/b", "/a/b")   --> true
```

## Taking apart

These are textual: nothing is normalized or looked up.

### path.dirname

```luau
path.dirname(p: string): string
```

```luau
path.dirname("/a/b/c.txt") --> "/a/b"
path.dirname("a")          --> "."
path.dirname("/")          --> "/"
```

### path.basename

```luau
path.basename(p: string, suffix: string?): string
```

The last segment, with `suffix` removed if it ends with it.

```luau
path.basename("/a/b/c.txt")         --> "c.txt"
path.basename("/a/b/c.txt", ".txt") --> "c"
```

### path.extname

```luau
path.extname(p: string): string
```

```luau
path.extname("/a/b/c.tar.gz") --> ".gz"
```

### path.stem

```luau
path.stem(p: string): string
```

The base name without its extension.

```luau
path.stem("/a/b/c.tar.gz") --> "c.tar"
```

### path.withExtension

```luau
path.withExtension(p: string, ext: string): string
```

Replaces the extension. An empty `ext` removes it.

```luau
path.withExtension("a/b.txt", "md") --> "a/b.md"
path.withExtension("a/b.txt", "")   --> "a/b"
```

### path.isAbsolute

```luau
path.isAbsolute(p: string): boolean
```

### path.components

```luau
path.components(p: string): { string }
```

```luau
path.components("/a/b/../c") --> { "/", "a", "b", "..", "c" }
```

### path.parse

```luau
path.parse(p: string): { root: string, dir: string, base: string, ext: string, name: string }
```

```luau
path.parse("/a/b.txt") --> { root = "/", dir = "/a", base = "b.txt", ext = ".txt", name = "b" }
```

### path.format

```luau
path.format(parts: { root: string?, dir: string?, base: string?, ext: string?, name: string? }): string
```

The reverse of `parse`.

```luau
path.format({ dir = "/a", name = "b", ext = "txt" }) --> "/a/b.txt"
```

## Conversion and PATH-style lists

### path.toPosix / path.toNative

```luau
path.toPosix(p: string): string
path.toNative(p: string): string
```

Convert separators to `/`, or to the style's own separator. Only the `win32` style changes
anything.

```luau
path.win32.toPosix("a\\b")  --> "a/b"
path.win32.toNative("a/b")  --> "a\\b"
```

### path.splitList

```luau
path.splitList(list: string): { string }
```

Splits a `PATH`-style list on `path.delimiter`. Empty entries are dropped.

```luau
path.splitList("/bin:/usr/bin") --> { "/bin", "/usr/bin" }
```

### path.joinList

```luau
path.joinList(entries: { string }): string
```

```luau
path.joinList({ "/bin", "/usr/bin" }) --> "/bin:/usr/bin"
```
