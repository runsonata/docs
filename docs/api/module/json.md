# @sonata/json

Parse, serialize and edit JSON.

```luau
local json = require("@sonata/json")

local data = json.decode('{"a":[1,2,{"b":null}]}')
print(json.get(data, "a[3].b") == json.null) --> true
print(json.encode({ x = 1, y = { true, "s" } })) --> {"x":1,"y":[true,"s"]}
```

**Errors:** functions raise on invalid input. Decode errors give the line and column.

## Mapping between JSON and Luau

| JSON | Luau |
|---|---|
| object | table with string keys |
| array | table with keys `1..n` |
| string | string |
| number | number |
| `true` / `false` | boolean |
| `null` | `json.null` |

Since a Luau table can't hold `nil`, JSON `null` is represented by the sentinel `json.null`.

When encoding, a table is an **array** if its keys are exactly `1..n`, and an **object**
otherwise. An empty table encodes as `[]`. To force one or the other, tag the table with
[`json.array`](#jsonarray-jsonobject) or [`json.object`](#jsonarray-jsonobject). Tables produced
by `json.decode` are tagged, so `{}` and `[]` survive a round trip.

Object keys are sorted when encoding, so the output is deterministic. `NaN`, infinities,
functions and other non-JSON values can't be encoded. Deeply nested (or cyclic) tables are
rejected.

## json.null

A unique value standing for JSON `null`.

## json.decode

```luau
json.decode(text: string): any
```

Parses a JSON document.

```luau
json.decode('[1, "two", null]') --> { 1, "two", json.null }
```

## json.encode

```luau
json.encode(value: any, options: { indent: (number | string)? }?): string
```

Serializes a value. Without `indent`, the output is compact. `indent` is a number of spaces,
or a string such as `"\t"`, for pretty printing.

```luau
print(json.encode({ name = "sonata", tags = { "luau" } }, { indent = 2 }))
--[[
{
  "name": "sonata",
  "tags": [
    "luau"
  ]
}
]]
```

## Paths

`get`, `set` and `delete` address values with a path: either a string like `"a.b[2].c"`
(dot-separated keys, 1-based `[index]` for arrays) or an array of segments like
`{ "a", "b", 2, "c" }`. Use the array form for keys that contain `.` or `[`.

### json.get

```luau
json.get(value: any, path: string | { string | number }, default: any?): any
```

Reads the value at `path`, or returns `default` (`nil`) if any part of the path is missing.

```luau
local port = json.get(config, "server.port", 8080)
```

### json.set

```luau
json.set(root: table, path: string | { string | number }, value: any): table
```

Writes `value` at `path` in place, creating missing objects and arrays on the way, and returns
`root`. An array index must name an existing element or the next free one (to append).

```luau
local t = {}
json.set(t, "a.b", 1)        --> { a = { b = 1 } }
json.set(t, "list[1]", "x")  --> { a = { b = 1 }, list = { "x" } }
```

### json.delete

```luau
json.delete(root: table, path: string | { string | number }): any
```

Removes the value at `path` in place and returns it. Removing from an array shifts the
following elements down.

## json.merge

```luau
json.merge(target: table, patch: table): table
```

Applies a [JSON Merge Patch (RFC 7396)](https://www.rfc-editor.org/rfc/rfc7396) to `target` in
place and returns it. Objects are merged recursively, `json.null` in the patch deletes a key,
and anything else replaces the value.

```luau
local config = { a = 1, b = { c = 2 } }
json.merge(config, { a = json.null, b = { d = 3 } })
--> { b = { c = 2, d = 3 } }
```

## json.clone

```luau
json.clone(value: any): any
```

A deep copy, keeping array/object tags.

## json.array / json.object

```luau
json.array(t: table?): table
json.object(t: table?): table
```

Tag a table (a new empty one if `t` is omitted) so it always encodes as an array (`[]`) or an
object (`{}`), whatever its contents.

```luau
json.encode({ items = json.array() })  --> {"items":[]}
json.encode({ meta = json.object() })  --> {"meta":{}}
```
