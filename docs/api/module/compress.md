# @sonata/compress

Compression and decompression (gzip, zlib, raw deflate and zstd), tar and zip archives,
streaming, password protection and checksums.

```luau
local compress = require("@sonata/compress")

local blob = compress.compress(string.rep("hello ", 1000))
print(#blob < 100)                     --> true (6000 bytes in)
print(compress.decompress(blob):sub(1, 11)) --> "hello hello"
```

**Errors:** functions raise on invalid arguments, corrupt data, and output larger than the
allowed maximum.

**Buffers.** Data can be a string or a `buffer`, and what comes back is the same kind as what
went in: compressing a buffer gives a buffer, unpacking an archive held in a buffer gives
entries whose `data` are buffers. Passwords can be either too.

## Formats

| Format | Levels (min–max, default) | Detected automatically |
|---|---|---|
| `"gzip"` (default) | 0–9, 6 | yes |
| `"zlib"` | 0–9, 6 | yes |
| `"deflate"` (raw) | 0–9, 6 | no: name it when decompressing |
| `"zstd"` | 1–22, 3 | yes |

A **level** is a whole number in the format's range, or one of `"fast"`, `"default"` and
`"best"`, which mean the same thing in every format. For gzip/zlib/deflate, level 0 stores
without compressing; `"fast"` is level 1.

Output is byte-identical on every OS: the gzip header carries no timestamp or OS ID.

**Decompression bombs.** `maxSize` caps the output of every decompression call. It defaults to
256 MiB and can be raised up to 1 GiB. For a [decoder](#compressdecoder), that's each call to
`write` or `finish`, not the stream as a whole.

## compress.compress

```luau
compress.compress(data: string | buffer, format: string?, level: (number | string)?, password: (string | buffer)?): string | buffer
```

Compresses `data` (default: gzip at the default level). With a `password`, the result is also
encrypted; `format` and `level` may stay `nil`.

```luau
compress.compress(text)                       -- gzip, default level
compress.compress(text, "zstd", "best")       -- zstd, highest level
compress.compress(text, nil, nil, "hunter2")  -- gzip, password-protected
```

## compress.decompress

```luau
compress.decompress(data: string | buffer, format: string?, maxSize: number?, password: (string | buffer)?): string | buffer
```

Decompresses `data`. Without `format`, it is detected from the data's magic bytes (raw
`deflate` has none and must be named). For password-protected data, give the password; the
format is stored inside the encrypted data.

Like their command-line tools, gzip members and zstd frames placed back to back decompress as
one. Anything else after the end of the data raises instead of being dropped, so to read a
compressed stream embedded in something bigger, cut it out first.

```luau
compress.decompress(blob)                       -- format sniffed
compress.decompress(blob, "deflate", 1e6)       -- raw deflate, output capped at 1 MB
compress.decompress(blob, nil, nil, "hunter2")  -- password-protected
```

## Passwords

Give `compress.compress` a password and it encrypts what it compressed, with XChaCha20-Poly1305
and a key derived from the password with Argon2id. The password is needed to read the data back,
and the data can't be changed without `compress.decompress` noticing: a wrong password and
tampering both raise the same error.

Deriving the key is slow on purpose, because that's what makes guessing passwords expensive.
Each call given a password takes around a second and needs 256 MiB of free memory, and blocks
while it runs. Streaming doesn't support passwords.

### compress.isEncrypted

```luau
compress.isEncrypted(data: string | buffer): boolean
```

Whether `data` is password-protected.

## Streaming

For data that arrives in pieces, or is too big to hold twice in memory, use an encoder or a
decoder. Feed chunks of any size; each call returns the output that is ready so far.

### compress.encoder

```luau
compress.encoder(format: string?, level: (number | string)?): (write: (chunk: string) -> string, finish: () -> string, flush: () -> string)
```

```luau
local write, finish = compress.encoder("gzip", 6)
local blob = write("chunk 1") .. write("chunk 2") .. finish()
```

Each call answers in the kind of value the last chunk written was, so writing buffers gets
buffers back from `write`, `flush` and `finish` alike.

An encoder holds on to what it's given until it has enough to compress well. `flush` returns
everything written so far in a form the other side can decode right away, without ending the
stream: use it when a reader is waiting, such as a log or a response sent while it's being
made. Each flush costs a few bytes, so don't flush after every small write.

### compress.decoder

```luau
compress.decoder(format: string?, maxSize: number?): (write: (chunk: string) -> string, finish: () -> string)
```

`maxSize` caps what each `write` or `finish` call returns. `finish()` checks that the stream
ended properly and raises if it was truncated.

```luau
local fs = require("@sonata/fs")

local write, finish = compress.decoder("gzip")
local out = {}
for _, chunk in fs.openReader("big.gz"):chunks() do
    table.insert(out, write(chunk))
end
table.insert(out, finish())
```

### compress.decodeStream

```luau
compress.decodeStream(reader: Reader, format: string?, maxSize: number?): Reader
```

A [reader](stream.md#readers-and-writers) of the decompressed contents of `reader`: a file, a
socket, a response, anything with `read`. `format` defaults to gzip, and `maxSize` caps each
piece, as for a decoder. Reading raises if the data is damaged or cut short. Closing it closes
`reader`.

```luau
local stream = require("@sonata/stream")

for line in stream.lines(compress.decodeStream(fs.open("app.log.gz"))) do
    print(line)
end
```

### compress.encodeStream

```luau
compress.encodeStream(writer: Writer, format: string?, level: (number | string)?): Writer
```

A [writer](stream.md#readers-and-writers) that compresses what's written to it into `writer`.
It also has `flush()`, as an encoder does. `close()` ends the compressed data but leaves
`writer` open, so a file can still be written to or closed afterwards.

```luau
local file = fs.open("out.gz", "w")
local gzip = compress.encodeStream(file)
gzip:write("hello\n")
gzip:close()
file:close()
```

## Archives

`compress.tar` and `compress.zip` turn a list of entries into an archive and back, in memory.
They never touch the disk: reading the files to pack and writing out the unpacked ones is up to
[`@sonata/fs`](fs.md), so a program only gets file access if it's allowed `fs`.

```luau
type Entry = {
    name: string,       -- "docs/readme.md": relative, with / between folders
    kind: string?,      -- "file" (default), "directory", "symlink", "hardlink" or "other"
    data: (string | buffer)?, -- a file's contents
    target: string?,    -- where a symlink points, or the entry a hard link shares contents with
    mode: number?,      -- permission bits: default 0644, 0755 for directories, 0777 for symlinks
    modified: number?,  -- Unix seconds: default 1980-01-01
}
```

A name ending in `/` is a directory, unless `kind` says otherwise. Unpacked entries always have
`name`, `kind`, `data` (`""` if it isn't a file), `mode` and `modified`, and `target` for links,
so they can be packed again as they are. Times default to 1980 rather than now so that the same
entries always make the same archive, byte for byte.

Luau has no octal literals, so give modes as `fs.modes.executable`, `493`, or
`tonumber("755", 8)`.

Packing a folder:

```luau
local fs = require("@sonata/fs")

local entries = {}
for item in fs.walk("site") do
    if item.kind ~= "other" then
        local stat = fs.lstat(item.fullPath)
        table.insert(entries, {
            name = item.path,
            kind = item.kind,
            data = if item.kind == "file" then fs.readFile(item.fullPath) else nil,
            target = if item.kind == "symlink" then fs.readLink(item.fullPath) else nil,
            mode = stat.mode,
            modified = stat.modified,
        })
    end
end
fs.writeFile("site.tar.gz", compress.compress(compress.tar.pack(entries)))
```

Unpacking into one:

```luau
local path = require("@sonata/path")

for _, entry in compress.tar.unpack(fs.readFile("site.tar.gz")) do
    local where = path.join("out", entry.name)
    if entry.kind == "directory" then
        fs.makeDir(where, true)
    elseif entry.kind == "file" then
        fs.makeDir(path.dirname(where), true)
        fs.writeFile(where, entry.data)
        fs.chmod(where, entry.mode)
    elseif entry.kind == "symlink" then
        fs.symlink(entry.target, where)
    end
end
```

**Unpacking is safe to join to a folder.** An archive can name a file `../../.bashrc` or
`/etc/passwd`, or hold a link to somewhere outside and then a file "inside" that link. Unpacking
raises on all of these: names that are absolute or contain `..` (with either `/` or `\`), and
symlinks that point to an absolute path or out of the folder. Setuid, setgid and sticky bits are
dropped. `{ trusted = true }` skips these checks; use it only for archives you made yourself.

Both formats are read and written whole, in memory, so an archive has to fit in a string
(under 1 GiB). `maxSize` (default 256 MiB, up to 1 GiB) caps what unpacking may produce: for tar,
the archive after decompression; for zip, the total size of its entries.

### compress.tar.pack / compress.tar.unpack

```luau
compress.tar.pack(entries: { Entry }): string
compress.tar.unpack(data: string | buffer, options: { maxSize: number?, trusted: boolean? }?): { Entry }
```

`pack` writes a POSIX (ustar) archive, adding pax records for names longer than ustar holds and
for times before 1970. Owners are written as 0 and aren't read back: whoever unpacks the files
owns them. For a `.tar.gz` or `.tar.zst`, give what `pack` returns to
[`compress.compress`](#compresscompress).

`unpack` reads ustar, pax, GNU and old v7 archives. A gzip or zstd archive is decompressed
first, so `compress.tar.unpack(fs.readFile("x.tar.gz"))` works. xz and bzip2 aren't supported,
and the error says which one it was. Devices, FIFOs and other special entries come back with
kind `"other"` and no data.

### compress.zip.pack / compress.zip.unpack

```luau
compress.zip.pack(entries: { Entry }, level: (number | string)?): string
compress.zip.unpack(data: string | buffer, options: { maxSize: number?, trusted: boolean? }?): { Entry }
```

`pack` deflates each file at `level` (default 6), and stores it instead where that's smaller,
or for every file at level 0. Modes and symlinks are kept the way Unix zip tools keep them.
zip has no hard links, so `pack` refuses them.

`unpack` reads stored, deflate and zstd entries, zip64 archives, and archives with something
else in front of them, such as a self-extracting program. Every entry's CRC is checked.
Encrypted entries and other methods (bzip2, lzma, xz, ...) raise. zip times are DOS times,
which have no time zone: `pack` writes them as UTC and adds a timestamp in seconds, and `unpack`
uses that timestamp when there is one, or reads the DOS time as UTC.

## Inspection

### compress.detect

```luau
compress.detect(data: string | buffer): string?
```

The format of `data` from its magic bytes: `"gzip"`, `"zlib"`, `"zstd"`, or `nil`. For
password-protected data, the format inside it.

### compress.formats

```luau
compress.formats(): { string }
```

Every format: `{ "gzip", "zlib", "deflate", "zstd" }`.

### compress.levels

```luau
compress.levels(format: string?): (number, number, number)
```

The minimum, maximum and default level of a format (default gzip).

```luau
compress.levels("zstd") --> 1, 22, 3
```

## Checksums

### compress.crc32

```luau
compress.crc32(data: string | buffer, seed: number?): number
```

The CRC-32 of `data`. Pass a previous result as `seed` to checksum data in pieces.

```luau
compress.crc32("abc")                        --> 891568578
compress.crc32("c", compress.crc32("ab"))    --> 891568578
```

### compress.adler32

```luau
compress.adler32(data: string | buffer, seed: number?): number
```

The Adler-32 checksum of `data`, with the same incremental `seed`.

```luau
compress.adler32("abc") --> 38600999
```
