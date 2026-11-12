# @sonata/serde

Parse, serialize and convert structured text (YAML, TOML, INI, CSV, TSV, XML), plus a toolkit
for writing your own formats. For JSON, see [`@sonata/json`](json.md).

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
| `"xml"` | XML documents, as a tree of elements. See [XML](#xml). |

### XML

XML doesn't map onto tables the way the other formats do, so a document is a tree of elements,
each a table with three fields:

```luau
local doc = serde.decode("xml", [[
<catalog>
  <book id="b1">
    <title>Dune</title>
    <note>A <b>classic</b>.</note>
  </book>
</catalog>
]])

--> {
-->   name = "catalog", attributes = {}, children = {
-->     { name = "book", attributes = { id = "b1" }, children = {
-->       { name = "title", attributes = {}, children = { "Dune" } },
-->       { name = "note", attributes = {}, children = {
-->         "A ", { name = "b", attributes = {}, children = { "classic" } }, ".",
-->       } },
-->     } },
-->   },
--> }
```

- `children` holds elements and strings, in document order. Entities, character references and
  CDATA sections become plain text, and line endings become `"\n"`.
- Whitespace between child elements, the indentation of the file, is left out, unless the
  [`whitespace`](#options) option is set. An element with only whitespace in it keeps it.
- Comments, processing instructions and the DOCTYPE are skipped. Namespace prefixes stay part of
  the name (`"svg:rect"`), and `xmlns` declarations are ordinary attributes.
- Only the five standard entities (`&amp;` `&lt;` `&gt;` `&quot;` `&apos;`) and character
  references are expanded. A DTD that declares entities is refused, so a document can't pull in
  external files or expand into gigabytes.
- Elements can be nested 100 deep.

`serde.encode("xml", element)` writes the same shape back. `attributes` and `children` may be
left out, and attribute values and text may be numbers or booleans. An element whose content is
only elements is indented ([`pretty`](#options)); one with text in it is written as it is, so
mixed content keeps its exact spacing.

```luau
print(serde.encode("xml", {
    name = "feed",
    attributes = { version = 2 },
    children = {
        { name = "item", children = { "First & best" } },
        { name = "item", attributes = { draft = true } },
    },
}))
--> <?xml version="1.0" encoding="UTF-8"?>
--> <feed version="2">
-->   <item>First &amp; best</item>
-->   <item draft="true"/>
--> </feed>
```

A small helper goes a long way for reading:

```luau
-- The first child element called `name`, and the text inside an element.
local function child(element, name)
    for _, kid in element.children do
        if type(kid) == "table" and kid.name == name then
            return kid
        end
    end
    return nil
end

local function text(element)
    local parts = {}
    for _, kid in element.children do
        table.insert(parts, if type(kid) == "string" then kid else text(kid))
    end
    return table.concat(parts)
end

print(text(child(child(doc, "book"), "note"))) --> A classic.
```

## serde.null

A unique value standing for `null`, since Luau tables can't hold `nil`.

## serde.decode

```luau
serde.decode(format: string | Format, text: string | buffer, options: Options?): any
```

Parses `text`.

## serde.csvReader

```luau
serde.csvReader(reader: Reader, options: Options?): () -> { [any]: any }?
```

The rows of CSV from a [reader](stream.md#readers-and-writers), one at a time, so a file of any
size can be read while only a row is in memory. `header`, `typed` and `delimiter` mean what they
mean for `decode` (for TSV, `delimiter = "\t"`): with a header, each row is a table keyed by its
columns; without one, an array of its fields. Quoted fields may hold line breaks, and a piece
of input can end anywhere, even in the middle of one.

```luau
local fs = require("@sonata/fs")

for row in serde.csvReader(fs.open("people.csv"), { typed = true }) do
    print(row.name, row.age)
end
```

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
| `indent: number` | yaml, xml encode | Indentation, 2 to 8 (default 2). |
| `sort: boolean` | encode | Sort table keys (default `true`; `false` uses Luau's iteration order). |
| `dropNull: boolean` | decode | Leave out `null` entries of tables. Nulls in arrays stay `serde.null`. |
| `header: boolean` | csv, tsv | The first row is a header (default `true`): rows become tables keyed by column name. With `false`, rows are arrays. |
| `typed: boolean` | ini, csv, tsv | Turn numbers and booleans into values instead of strings (default `true` for ini, `false` for csv/tsv). |
| `delimiter: string` | csv | The field separator, one character (default `","`; tsv uses `"\t"`). |
| `whitespace: boolean` | xml decode | Keep whitespace-only text between child elements (default `false`). |
| `pretty: boolean` | xml encode | Put content that's only elements on lines of its own, indented (default `true`). |
| `declaration: boolean` | xml encode | Start with `<?xml version="1.0" encoding="UTF-8"?>` (default `true`). |

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
