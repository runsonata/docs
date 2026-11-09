# @sonata/stream

One shape for everything that produces or takes bytes, and helpers that work on all of them:
copying from one to another, reading lines, collecting, and building readers from readers.

```luau
local fs = require("@sonata/fs")
local stream = require("@sonata/stream")

stream.pipe(fs.open("in.bin"), fs.open("out.bin", "w"), { close = true })

for line in stream.lines(fs.open("notes.txt")) do
    print(line)
end
```

## Readers and writers

A **reader** is anything with a `read` method that returns the next piece (a string or a
`buffer`), or `nil` at the end. `read` may take `max`, the most the caller wants now: readers
that can honor it, and others may return more. A reader reports a failure by raising, or by
returning `nil` and a message.

A **writer** is anything with a `write(data)` method. It reports a failure by raising, or by
returning `nil` (or `false`) and a message. Readers and writers may also have `close()`.

There's nothing to register: a table with the right method works. These all fit already:

| Object | Reader | Writer |
|---|---|---|
| [`fs.File`](fs.md#fsopen) | `read` | `write` |
| [`fs.Reader`](fs.md#fsopenreader) | `read` (one chunk at a time) | |
| [Process pipes](process.md) | `child.stdout`, `child.stderr` | `child.stdin` |
| [Sockets](net.md#socket-methods) | `read` | `write` |
| [`net.request`](net.md) responses, with `stream = true` | `read` | |
| [`compress.decodeStream`](compress.md#compressdecodestream) / [`compress.encodeStream`](compress.md#compressencodestream) | `read` | `write` |

A reader also works as the `body` of a `net.request`, so a response can be piped straight into
another request.

## Copying

### stream.pipe

```luau
stream.pipe(reader: Reader, writer: Writer, options: { close: boolean?, chunkSize: number? }?): number
```

Copies everything from `reader` to `writer`, and returns the number of bytes copied. Pieces
pass through as they come, buffers included. `chunkSize` (default 64 KiB) is the `max` given to
each `read`. With `close = true`, both are closed at the end, also when copying fails; the error
raised is the first thing that went wrong.

Waiting for either side lets other tasks run, as everything else that waits does.

## Reading

### stream.readAll

```luau
stream.readAll(reader: Reader, max: number?): string
```

Everything left in `reader`, as one string. Raises once there is more than `max` bytes (default:
1 GiB - 1, the longest string Luau has).

### stream.lines

```luau
stream.lines(reader: Reader, keepEnding: boolean?): () -> string?
```

An iterator over the lines of `reader`, without their `"\n"` or `"\r\n"` unless `keepEnding`.
The last line comes out even if it has no ending.

```luau
for line in stream.lines(child.stdout) do
    print(line)
end
```

## Making readers and writers

### stream.fromString

```luau
stream.fromString(data: string | buffer): Reader
```

A reader over a string or a buffer. Its `read(max)` returns at most `max` bytes (default
64 KiB); `close()` makes it end.

### stream.fromFunction

```luau
stream.fromFunction(fn: (max: number?) -> (string | buffer)?): Reader
```

A reader that calls `fn(max)` for each piece. `fn` returns the next one, then `nil`.

### stream.collector

```luau
stream.collector(): Collector
```

A writer that keeps everything written to it. `collector:result()` returns it all as one string,
and `collector:size()` how many bytes that is.

### stream.discard

```luau
stream.discard(): Writer
```

A writer that throws away everything written to it.

## Readers from readers

### stream.transform

```luau
stream.transform(reader: Reader, fn: (piece) -> (string | buffer)?, finish: (() -> (string | buffer)?)?): Reader
```

A reader whose pieces are `fn(piece)` for each piece of `reader`. `fn` may return `""` or `nil`
to give nothing for a piece. When `reader` ends, `finish()` (if given) may return one last
piece. Closing it closes `reader`.

```luau
local shouted = stream.transform(fs.open("in.txt"), string.upper)
```

### stream.chain

```luau
stream.chain(...: Reader): Reader
```

A reader that gives everything from each reader in turn. Closing it closes them all.

### stream.limit

```luau
stream.limit(reader: Reader, count: number): Reader
```

A reader that ends after `count` bytes of `reader`, which stays open for whatever comes after.
It never asks for more than it still needs; a reader that returns more anyway loses the extra,
so use it on readers that honor `max` (files, sockets, pipes, `fromString`).
