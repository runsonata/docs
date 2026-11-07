# @sonata/term

The terminal and the standard streams: reading and writing, colors and styles, cursor control
and keyboard input.

```luau
local term = require("@sonata/term")
```

**Errors:** I/O failures never raise. Every method that can fail returns `nil` and a message
instead, so `nil` alone means end of input and `nil, message` means failure. Wrong arguments,
and using a stream in the wrong direction, still raise.

## Streams

`term.stdin`, `term.stdout` and `term.stderr`. Write methods only work on `stdout` and
`stderr`; read methods only on `stdin`.

### Writing

| Method | Description |
|---|---|
| `stream:write(...)` | Writes the values (strings and numbers only). Returns the stream, so calls chain. |
| `stream:writeLine(...)` | Like `write`, then a newline. |
| `stream:flush()` | Flushes buffered output. |

Each returns the stream, or `nil, message` on failure.

```luau
term.stdout:write("Loading... "):flush()
term.stderr:writeLine("warning: ", count, " files skipped")
```

Output goes through C stdio, so it stays in order with `print()` and with child processes.
Writing never flushes by itself: `stdout` is line-buffered on a terminal, so call `flush()` when
output must appear immediately.

### Reading

| Method | Returns |
|---|---|
| `stream:readLine(keepEnding: boolean?)` | The next line, without its ending unless `keepEnding` is `true`. `nil` at end of input. |
| `stream:read(count: number)` | Exactly `count` bytes, waiting until they've all arrived (fewer only at end of input). `nil` at end of input. |
| `stream:readSome(maxCount: number)` | Up to `maxCount` bytes, as soon as at least one is available. `nil` at end of input. |
| `stream:readAll()` | Everything until end of input (`""` if already there). |
| `stream:lines(keepEnding: boolean?)` | An iterator over lines. |

A line ends at `"\n"`, `"\r\n"` or a lone `"\r"`. Reading waits without blocking other tasks,
except `lines()`: an iterator can't let other tasks run.

```luau
for line in term.stdin:lines() do
    term.stdout:writeLine(line:upper())
end
```

`stdout` is flushed before every blocking read, so a prompt written with `write()` is visible.
Input is read directly from the OS through one shared buffer, so nothing else in the process
should read C `stdin`.

### Other stream methods

| Method | Returns |
|---|---|
| `stream:isTerminal(): boolean` | Whether the stream is a terminal. |
| `stream:size(): (number?, number?)` | Columns and rows, or `nil` if it isn't a terminal. |

## Prompts

### term.prompt

```luau
term.prompt(message: string): (string?, string?)
```

Writes `message` to stdout, flushes, then reads a line from stdin. `nil` at end of input.

```luau
local name = term.prompt("Name: ")
```

### term.password

```luau
term.password(message: string, mask: string?): string?
```

Like `prompt`, without echoing what is typed. If `mask` is given (e.g. `"*"`), it is shown for
each character. Returns `nil` at end of input or on Ctrl+C.

### term.size

```luau
term.size(): (number?, number?)
```

The terminal's columns and rows, or `nil` if there is no terminal.

## Colors and styles

### term.style

```luau
term.style(text: string, ...: string): string
```

Wraps `text` in the given styles, at the color level of stdout. At level 0 (no colors) the
text comes back unchanged.

```luau
print(term.style("ok", "bold", "green"))
print(term.style("warning", "#ff8800"))
print(term.style(" selected ", "bgBlue", "white"))
```

| Kind | Styles |
|---|---|
| Modifiers | `"bold"` `"dim"` `"italic"` `"underline"` `"blink"` `"inverse"` `"hidden"` `"strikethrough"` |
| Colors | `"black"` `"red"` `"green"` `"yellow"` `"blue"` `"magenta"` `"cyan"` `"white"` `"gray"`, and `"brightRed"` ... `"brightWhite"` |
| Backgrounds | `"bg"` + any color: `"bgRed"`, `"bgBrightBlue"`, ... |
| Exact colors | `"#ff8800"` or `"#f80"` (text), `"bg:#ff8800"` (background), `"fg:208"` / `"bg:208"` (256-color palette) |

Exact colors are turned into the nearest color the terminal can show.

### term.colorLevel

```luau
term.colorLevel(stream: Stream?): number
```

The color support of a stream (default stdout): `0` none, `1` 16 colors, `2` 256 colors, `3`
true color. Honors `NO_COLOR`, `FORCE_COLOR`, `TERM` and `COLORTERM`, and is `0` when the stream
isn't a terminal.

### term.setColorLevel

```luau
term.setColorLevel(level: number?): ()
```

Forces a color level for every stream. `nil` goes back to detecting it.

### term.strip

```luau
term.strip(text: string): string
```

Removes escape sequences.

### term.width

```luau
term.width(text: string): number
```

The number of columns `text` takes on screen. Escape sequences take none; wide characters
(CJK, emoji) take 2.

## Cursor and screen

These write to stdout, and only if stdout is a terminal.

| Function | Description |
|---|---|
| `term.moveTo(column: number, row: number)` | Moves the cursor (1-based). |
| `term.move(dx: number, dy: number)` | Moves the cursor relative to where it is. |
| `term.hideCursor()`, `term.showCursor()` | |
| `term.saveCursor()`, `term.restoreCursor()` | |
| `term.clear(what: string?)` | `"screen"` (default: clears and moves home), `"below"`, `"above"`, `"line"`, `"lineRight"`, `"lineLeft"`. |
| `term.altScreen(on: boolean)` | Switches to or from the alternate screen. |
| `term.setTitle(text: string)` | Sets the window title. |
| `term.bell()` | Rings the bell. |
| `term.cursorPosition(): (number?, number?)` | Asks the terminal where the cursor is. `nil` if it doesn't answer. |

### term.ansi

The same sequences as strings, for building output yourself:

| Member | Description |
|---|---|
| `term.ansi.moveTo(c, r)`, `term.ansi.move(dx, dy)`, `term.ansi.clear(what?)` | Functions returning the sequence. |
| `term.ansi.style(...)` | Just the opening codes for the given styles. |
| `term.ansi.hideCursor`, `.showCursor`, `.saveCursor`, `.restoreCursor`, `.altScreenOn`, `.altScreenOff`, `.reset` | Constant strings. |

## Keyboard

### term.rawMode

```luau
term.rawMode(on: boolean): boolean
```

Turns raw mode on or off and returns the previous state. In raw mode there is no line editing
and no echo, and Ctrl+C arrives as a key instead of a signal. The terminal is restored when the
program exits.

### term.isRaw

```luau
term.isRaw(): boolean
```

### term.readKey

```luau
term.readKey(timeout: number?): Key?

type Key = {
    name: string,
    char: string?,   -- set for printable keys
    ctrl: boolean,
    alt: boolean,
    shift: boolean,
    sequence: string, -- the raw bytes
}
```

Waits for one key press, switching to raw mode for the duration if it isn't on already.
Returns `nil` on timeout or end of input.

`name` is the character itself (`"a"`, `"A"`, `"é"`) or one of `"enter"` `"tab"` `"backspace"`
`"escape"` `"space"` `"up"` `"down"` `"left"` `"right"` `"home"` `"end"` `"pageUp"` `"pageDown"`
`"insert"` `"delete"` `"f1"` ... `"f12"`. Ctrl+letter gives the letter with `ctrl = true`.

```luau
while true do
    local key = term.readKey()
    if not key or key.name == "escape" or (key.ctrl and key.name == "c") then
        break
    end
    print(key.name)
end
```
