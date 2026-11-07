# @sonata/serde

Parse, serialize and convert structured text (YAML, TOML, INI, CSV, TSV), plus a toolkit for
writing your own formats. For JSON, see [`@sonata/json`](json.md).

```luau
local serde = require("@sonata/serde")

local config = serde.decode("toml", [[
title = "Example"

[server]
host = "localhost"
port = 8080
]])
print(config.server.port) --> 8080

print(serde.encode("yaml", config))
```

**Errors:** functions raise on invalid input, with the line and column of the problem.

## Built-in formats

| Name | Notes |
|---|---|
| `"yaml"` (also `"yml"`) | YAML documents. |
| `"toml"` | TOML. |
| `"ini"` | INI files: sections become nested tables. |
| `"csv"` | Comma-separated values. |
| `"tsv"` | Tab-separated values. |

## serde.null

A unique value standing for `null`, since Luau tables can't hold `nil`.

## serde.decode

```luau
serde.decode(format: string | Format, text: string, options: Options?): any
```

Parses `text`.

## serde.encode

```luau
serde.encode(format: string | Format, value: any, options: Options?): string
```

Serializes `value`.

## serde.convert

```luau
serde.convert(from: string | Format, to: string | Format, text: string, options: Options?): string
```

Decodes and re-encodes in one call.

```luau
local toml = serde.convert("yaml", "toml", fs.readFile("config.yaml"))
```

## serde.formats

```luau
serde.formats(): { string }
```

The names of every available format, built-in and registered.

## Options

Every option is optional. Unknown keys are ignored, and the same table is passed on to custom
formats, so they can define options of their own.

| Option | Applies to | Description |
|---|---|---|
| `indent: number` | yaml encode | Indentation, 2 to 8 (default 2). |
| `sort: boolean` | encode | Sort table keys (default `true`; `false` uses Luau's iteration order). |
| `dropNull: boolean` | decode | Leave out `null` entries of tables. Nulls in arrays stay `serde.null`. |
| `header: boolean` | csv, tsv | The first row is a header (default `true`): rows become tables keyed by column name. With `false`, rows are arrays. |
| `typed: boolean` | ini, csv, tsv | Turn numbers and booleans into values instead of strings (default `true` for ini, `false` for csv/tsv). |
| `delimiter: string` | csv | The field separator, one character (default `","`; tsv uses `"\t"`). |

```luau
local rows = serde.decode("csv", "name,age\nAda,36\nAlan,41", { typed = true })
print(rows[2].name, rows[2].age) --> Alan 41
```

## Custom formats

Wherever a format name is accepted, a table with `decode` and/or `encode` functions works too:

```luau
type Format = {
    decode: ((text: string, options: Options?) -> any)?,
    encode: ((value: any, options: Options?) -> string)?,
}
```

### serde.register

```luau
serde.register(name: string, format: Format?): ()
```

Makes a format available by name. Registered names take precedence over built-in ones. Passing
`nil` unregisters it.

```luau
serde.register("kv", {
    decode = function(text)
        local result = {}
        for key, value in text:gmatch("([%w_]+)%s*=%s*([^\n]*)") do
            result[key] = value
        end
        return result
    end,
    encode = function(value)
        local w = serde.writer()
        for key, v in value do
            w:line(key, " = ", tostring(v))
        end
        return w:str()
    end,
})

print(serde.decode("kv", "a = 1\nb = 2").b) --> "2"
```

An unregistered table works inline too: `serde.decode({ decode = myDecoder }, text)`.

## Toolkit for writing formats

### serde.scanner

```luau
serde.scanner(text: string): Scanner
```

A cursor over `text`, for writing parsers.

| Member | Description |
|---|---|
| `s.text` | The text being scanned. |
| `s.pos` | The current position, 0-based. Assign to it to backtrack. |
| `s:eof(): boolean` | Whether the end has been reached. |
| `s:peek(n: number?): string` | The next `n` characters (default 1), without consuming them. |
| `s:next(n: number?): string` | Consumes and returns the next `n` characters (default 1). |
| `s:eat(literal: string): boolean` | Consumes `literal` if the text continues with it. |
| `s:expect(literal: string): string` | Like `eat`, but raises (with the position) if the literal isn't next. |
| `s:take(set: string): string` | Consumes characters while they are in `set`. |
| `s:line(): string` | The rest of the current line, without its newline; moves to the start of the next line. |
| `s:rest(): string` | Everything not consumed yet. Doesn't move. |
| `s:where(): (number, number)` | The current line and column, both 1-based. |
| `s:fail(message: string)` | Raises `"message (line L, column C)"`. |

A `set` for `take` lists literal characters, ranges like `a-z`, and the classes `%s` `%d` `%a`
`%w` `%x`. A leading `^` negates it: `"^,\n"` takes everything up to a comma or newline.

```luau
local s = serde.scanner("width=80")
local key = s:take("%w_")  --> "width"
s:expect("=")
local value = s:take("%d") --> "80"
```

### serde.writer

```luau
serde.writer(indent: (string | number)?): Writer
```

A string builder with indentation, for writing encoders. Every method returns the writer, so
calls chain.

| Method | Description |
|---|---|
| `w:write(...)` | Appends strings, numbers and booleans as they are. |
| `w:line(...)` | Writes the current indentation, the values, then a newline. With no values, a blank line. |
| `w:indent(n: number?)` | Indents following lines by `n` more levels (default 1). |
| `w:dedent(n: number?)` | Indents following lines by `n` fewer levels (default 1). |
| `w:str(): string` | The text so far. `tostring(w)` works too. |

### Helpers

| Function | Description |
|---|---|
| `serde.escape(text: string, quote: string?): string` | Escapes a string the way most formats do (`\n`, `\"`, ...). |
| `serde.unescape(text: string): string` | Reverses `escape`. Understands `\n \t \r \b \f \e \0 \" \' \\ \/ \xNN \uNNNN \UNNNNNNNN`. |
| `serde.formatNumber(n: number): string` | The shortest text that reads back as the same number. |
| `serde.isArray(t: table): boolean` | `true` for `{}` and for tables whose keys are exactly `1..n`. |
