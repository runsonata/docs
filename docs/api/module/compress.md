# @sonata/compress

Compression and decompression (gzip, zlib, raw deflate and zstd), streaming, password
protection and checksums.

```luau
local compress = require("@sonata/compress")

local blob = compress.compress(string.rep("hello ", 1000))
print(#blob < 100)                     --> true (6000 bytes in)
print(compress.decompress(blob):sub(1, 11)) --> "hello hello"
```

**Errors:** functions raise on invalid arguments, corrupt data, and output larger than the
allowed maximum.

## Formats

| Format | Levels (min–max, default) | Detected automatically | Availability |
|---|---|---|---|
| `"gzip"` (default) | 0–9, 6 | yes | always |
| `"zlib"` | 0–9, 6 | yes | always |
| `"deflate"` (raw) | 0–9, 6 | no: name it when decompressing | always |
| `"zstd"` | 1–22, 3 | yes | when Sonata was built with `SONATA_COMPRESS_ZSTD` (libzstd) |

A **level** is a number in the format's range, or one of `"fast"`, `"default"` and `"best"`,
which mean the same thing in every format. For gzip/zlib/deflate, level 0 stores without
compressing; `"fast"` is level 1.

Output is byte-identical on every OS: the gzip header carries no timestamp or OS ID.

**Decompression bombs.** `maxSize` caps the output of every decompression call. It defaults to
256 MiB and can be raised up to 1 GiB.

## compress.compress

```luau
compress.compress(data: string, format: string?, level: (number | string)?, password: string?): string
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
compress.decompress(data: string, format: string?, maxSize: number?, password: string?): string
```

Decompresses `data`. Without `format`, it is detected from the data's magic bytes (raw
`deflate` has none and must be named). For password-protected data, give the password; the
format is stored inside the encrypted data.

```luau
compress.decompress(blob)                       -- format sniffed
compress.decompress(blob, "deflate", 1e6)       -- raw deflate, output capped at 1 MB
compress.decompress(blob, nil, nil, "hunter2")  -- password-protected
```

## Passwords

Password protection needs Sonata built with `SONATA_COMPRESS_CRYPTO` (libsodium). Streaming
doesn't support passwords.

### compress.isEncrypted

```luau
compress.isEncrypted(data: string): boolean
```

Whether `data` is password-protected.

## Streaming

For data that arrives in pieces, or is too big to hold twice in memory, use an encoder or a
decoder. Feed chunks of any size; each call returns the output that is ready so far.

### compress.encoder

```luau
compress.encoder(format: string?, level: (number | string)?): (write: (chunk: string) -> string, finish: () -> string)
```

```luau
local write, finish = compress.encoder("gzip", 6)
local blob = write("chunk 1") .. write("chunk 2") .. finish()
```

### compress.decoder

```luau
compress.decoder(format: string?, maxSize: number?): (write: (chunk: string) -> string, finish: () -> string)
```

`finish()` checks that the stream ended properly and raises if it was truncated.

```luau
local fs = require("@sonata/fs")

local write, finish = compress.decoder("gzip")
local out = {}
for _, chunk in fs.openReader("big.gz"):chunks() do
    table.insert(out, write(chunk))
end
table.insert(out, finish())
```

## Inspection

### compress.detect

```luau
compress.detect(data: string): string?
```

The format of `data` from its magic bytes: `"gzip"`, `"zlib"`, `"zstd"`, or `nil`. For
password-protected data, the format inside it.

### compress.formats

```luau
compress.formats(): { string }
```

The formats available in this build, e.g. `{ "gzip", "zlib", "deflate", "zstd" }`.

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
compress.crc32(data: string, seed: number?): number
```

The CRC-32 of `data`. Pass a previous result as `seed` to checksum data in pieces.

```luau
compress.crc32("abc")                        --> 891568578
compress.crc32("c", compress.crc32("ab"))    --> 891568578
```

### compress.adler32

```luau
compress.adler32(data: string, seed: number?): number
```

The Adler-32 checksum of `data`, with the same incremental `seed`.

```luau
compress.adler32("abc") --> 38600999
```
