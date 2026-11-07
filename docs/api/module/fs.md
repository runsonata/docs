# @sonata/fs

Filesystem access: files, directories, metadata, globbing, watching and locking.

```luau
local fs = require("@sonata/fs")
```

**Errors:** every function raises a Luau error on failure (catch it with `pcall`), except the
`exists`, `isFile`, `isDir` and `isSymlink` queries, which answer `false`. Error messages use
the same wording on every OS whenever the OS has a portable name for the error
(`"no such file or directory"`, `"permission denied"`, ...).

**Paths** are UTF-8 strings and may use `/` everywhere (Windows also accepts `\`). Paths this
library returns (`realPath`, `cwd`, `tempDir`, `makeTempDir`, `readLink`) always use `/`.
Windows keeps its drive letter (`"C:/Users/me"`). File contents are binary-safe strings.

## Constants

| Name | Description |
|---|---|
| `fs.maxReadSize` | The largest file `readFile` accepts, in bytes (1 GiB - 1, the Luau string limit). |
| `fs.maxChunkSize` | The largest chunk a reader can produce, in bytes. |
| `fs.modes` | Permission presets for [`chmod`](#fschmod). |

`fs.modes`:

| Key | Value | Octal |
|---|---|---|
| `file` | `420` | `0644` |
| `executable` | `493` | `0755` |
| `directory` | `493` | `0755` |
| `private` | `384` | `0600` |
| `privateDirectory` | `448` | `0700` |
| `readOnly` | `292` | `0444` |

## Files

### fs.readFile

```luau
fs.readFile(path: string): string
```

Returns the whole contents of a file. Files larger than `fs.maxReadSize` are refused; use
[`openReader`](#fsopenreader) for those.

### fs.writeFile

```luau
fs.writeFile(path: string, contents: string): ()
```

Writes `contents` to a file, creating it or truncating it first.

### fs.appendFile

```luau
fs.appendFile(path: string, contents: string): ()
```

Appends to a file, creating it if it doesn't exist.

### fs.copyFile

```luau
fs.copyFile(from: string, to: string, overwrite: boolean?): ()
```

Copies a file. `overwrite` defaults to `true`; with `false`, copying onto an existing file is
an error.

### fs.removeFile

```luau
fs.removeFile(path: string): ()
```

Deletes a file. Read-only files are deleted on Windows too, as on POSIX.

### fs.move

```luau
fs.move(from: string, to: string): ()
```

Renames a file or directory. Across devices, it copies and then deletes.

## Chunked reading

For files too big to hold in memory at once, a reader returns them one chunk at a time.

```luau
local reader = fs.openReader("big.log", { size = 1024 * 1024 })
for index, chunk in reader:chunks() do
    process(chunk)
end
reader:close()
```

### Chunk specs

The optional `spec` argument decides the chunk size:

| Spec | Chunk size |
|---|---|
| `nil` or `"auto"` | File size / 64, rounded up to a multiple of 4 KiB, kept between 64 KiB and 4 MiB. |
| `{ count = n }` | Aim for `n` chunks: `ceil(size / n)` bytes each. The real count can be lower than `n`, never higher. |
| `{ size = n }` | Exactly `n` bytes per chunk (1 to `fs.maxChunkSize`); the last chunk may be shorter. |

### fs.chunkPlan

```luau
fs.chunkPlan(sizeOrPath: number | string, spec: ChunkSpec?): ChunkPlan

type ChunkPlan = {
    size: number,          -- total bytes
    chunkSize: number,     -- bytes per chunk
    chunkCount: number,    -- number of chunks (0 for an empty file)
    lastChunkSize: number, -- bytes in the last chunk
}
```

Works out how a file (or a size in bytes, without touching any file) would be split.

### fs.openReader

```luau
fs.openReader(path: string, spec: ChunkSpec?): Reader
```

Opens a regular file for chunked reading. The plan is fixed when the reader opens: if the file
shrinks afterwards, reading raises; bytes appended afterwards are not seen. A reader keeps its
file open until `close()` or until it is garbage collected.

| Method | Description |
|---|---|
| `reader:read(): string?` | The next chunk, or `nil` after the last one. |
| `reader:readChunk(index: number): string` | Chunk number `index` (1-based), in any order. |
| `reader:chunks()` | Iterator: `for index, chunk in reader:chunks() do ... end`. |
| `reader:rewind()` | Makes `read()` start again at chunk 1. |
| `reader:plan(): ChunkPlan` | The same table `fs.chunkPlan` returns. |
| `reader:close()` | Releases the file now. Calling it twice is fine. |

`read()`, `readChunk()` and `chunks()` don't disturb each other: only `read()` moves the
`read()` position.

## Directories

### fs.makeDir

```luau
fs.makeDir(path: string, recursive: boolean?): ()
```

Creates a directory. With `recursive`, missing parents are created and an existing directory
is fine; without it, the directory must not exist yet.

### fs.removeDir

```luau
fs.removeDir(path: string, recursive: boolean?): ()
```

Deletes a directory. Without `recursive`, it must be empty.

### fs.listDir

```luau
fs.listDir(path: string, recursive: boolean?): { string }
```

The names of the entries in a directory, sorted. With `recursive`, every entry below it, as
paths relative to `path` with `/` separators (`"sub/a.txt"`). Symlinks are listed, not
followed.

### fs.readDir

```luau
fs.readDir(path: string, recursive: boolean?): { { name: string, kind: Kind } }
```

Like `listDir`, but each entry is a table with its `name` and its `kind`
(`"file" | "directory" | "symlink" | "other"`).

### fs.copyDir

```luau
fs.copyDir(from: string, to: string, overwrite: boolean?): ()
```

Copies a directory recursively, merging into `to`. `overwrite` (default `true`) decides what
happens to files that already exist.

## Queries

### fs.exists

```luau
fs.exists(path: string): boolean
```

Whether something exists at `path`. Follows symlinks.

### fs.isFile / fs.isDir

```luau
fs.isFile(path: string): boolean
fs.isDir(path: string): boolean
```

Whether `path` is a regular file / a directory. Follow symlinks.

### fs.isSymlink

```luau
fs.isSymlink(path: string): boolean
```

### fs.stat / fs.lstat

```luau
fs.stat(path: string): Stat
fs.lstat(path: string): Stat

type Stat = {
    kind: "file" | "directory" | "symlink" | "other",
    size: number,     -- bytes; 0 for anything but regular files
    modified: number, -- Unix seconds
    mode: number,     -- permission bits
}
```

`stat` follows symlinks; `lstat` describes the link itself.

### fs.realPath

```luau
fs.realPath(path: string): string
```

The absolute path with every symlink resolved. The path must exist.

## Links and permissions

### fs.symlink

```luau
fs.symlink(target: string, link: string): ()
```

Creates a symbolic link at `link` pointing to `target`.

### fs.readLink

```luau
fs.readLink(path: string): string
```

The target of a symbolic link.

### fs.chmod

```luau
fs.chmod(path: string, mode: number): ()
```

Sets permission bits, e.g. `fs.chmod(p, fs.modes.executable)`.

!!! note "Windows"

    Windows has no permission bits, only a read-only attribute. `chmod` looks at the owner-write
    bit (`0200`) only: set means writable, clear means read-only. `stat().mode` is derived from
    that attribute: `0644`/`0444` for files, `0755`/`0555` for directories. `fs.modes.file` and
    `fs.modes.readOnly` round-trip on every OS.

## Process-level locations

### fs.cwd / fs.chdir

```luau
fs.cwd(): string
fs.chdir(path: string): ()
```

Get or change the current working directory.

### fs.tempDir

```luau
fs.tempDir(): string
```

The system's temporary directory.

### fs.makeTempDir

```luau
fs.makeTempDir(prefix: string?): string
```

Creates a new, empty, private directory inside the temporary directory and returns its path.
`prefix` defaults to `"sonata-"`.

## Finding files

### fs.walk

```luau
fs.walk(dir: string, options: WalkOptions?): () -> Entry?

type WalkOptions = {
    maxDepth: number?,                  -- default: unlimited (at least 1)
    followSymlinks: boolean?,           -- default false: links are reported, not entered
    filter: ((entry: Entry) -> boolean)?, -- false skips the entry (and a directory's contents)
    dirs: boolean?,                     -- default true: report directories too
}

type Entry = {
    path: string,     -- relative to dir: "sub/a.txt"
    fullPath: string, -- "src/sub/a.txt"
    name: string,     -- "a.txt"
    kind: "file" | "directory" | "symlink" | "other",
    depth: number,    -- 1 for entries directly inside dir
}
```

An iterator over everything below `dir`, depth first: a directory comes before its contents,
and names are sorted within each directory.

```luau
for entry in fs.walk("src", { filter = function(e) return e.name ~= "node_modules" end }) do
    if entry.kind == "file" then
        print(entry.path)
    end
end
```

### fs.glob

```luau
fs.glob(pattern: string, options: GlobOptions?): { string }

type GlobOptions = {
    cwd: string?,       -- where relative patterns start (default ".")
    dot: boolean?,      -- let wildcards match names starting with "." (default false)
    kind: ("file" | "directory")?, -- only return entries of this kind
    absolute: boolean?, -- return absolute paths (default false: as the pattern wrote them)
}
```

Returns the paths matching `pattern`, sorted.

| Syntax | Matches |
|---|---|
| `*` | Any characters except `/`. |
| `?` | One character. |
| `[abc]`, `[a-z]`, `[!abc]` | One character from a set, or not in it. |
| `**` | Any number of directories. |
| `{a,b}` | Either alternative. |
| `\` | Escapes the next character. |

Names starting with `.` only match patterns that spell out the dot, unless `dot = true`.

```luau
local sources = fs.glob("src/**/*.luau")
```

### fs.match

```luau
fs.match(pattern: string, path: string, options: { dot: boolean? }?): boolean
```

Tests a path against a glob pattern with the same rules, without touching the disk.

## Watching for changes

### fs.watch

```luau
fs.watch(path: string, options: WatchOptions?): Watcher

type WatchOptions = {
    recursive: boolean?, -- include subdirectories (default true)
    interval: number?,   -- seconds between checks (default 0.25)
}

type Event = {
    kind: "create" | "modify" | "remove",
    path: string,
    isDir: boolean,
}
```

Watches a file, or a directory and what is in it.

| Method | Description |
|---|---|
| `watcher:next(timeout: number?): Event?` | Waits for the next change. `nil` on timeout, or once the watcher is closed. Other tasks run while it waits. |
| `watcher:poll(): { Event }` | The changes since the last look, without waiting. |
| `watcher:close()` | Stops watching. |

Changes are found by comparing sizes and modification times every `interval`, so very fast
edits in between may show up as a single `"modify"`.

```luau
local watcher = fs.watch("src")
while true do
    local event = watcher:next()
    if not event then break end
    print(event.kind, event.path)
end
```

## Locking

Advisory file locks: they only work between programs that also lock.

### fs.lock

```luau
fs.lock(path: string, options: { shared: boolean?, timeout: number? }?): Lock?
```

Waits until the lock is acquired and returns it, or returns `nil` once `timeout` seconds have
passed (default: wait forever). `shared = true` takes a shared (read) lock instead of an
exclusive one. Other tasks run while it waits.

### fs.tryLock

```luau
fs.tryLock(path: string, options: { shared: boolean? }?): Lock?
```

Takes the lock if it is free, or returns `nil` immediately if someone else holds it.

| Method | Description |
|---|---|
| `lock:unlock()` | Releases the lock. |
| `lock:isLocked(): boolean` | Whether this lock is still held. |

The lock file is created if it doesn't exist and is left in place afterwards. A lock is
released by `unlock()`, when it is garbage collected, and when the program exits.
