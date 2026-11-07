# @sonata/regex

Regular expressions with ECMAScript syntax (the flavor JavaScript uses).

```luau
local regex = require("@sonata/regex")

regex.matches("2024-05-01", "\\d{4}-\\d{2}-\\d{2}") --> true
regex.replace("a1b22", "\\d+", "<$&>")               --> "a<1>b<22>", 2
```

The argument order is always `(text, pattern, ...)`. `flags` is an optional string; the
supported flag is `"i"` (case-insensitive).

**Errors:** an invalid pattern raises an error. Texts are limited to 64 KiB and patterns to
1024 bytes, because the underlying engine (`std::regex`) is recursive and very long inputs could
exhaust the native stack.

!!! tip

    Luau strings treat `\` as an escape, so a regex `\d` is written `"\\d"`. Raw string syntax
    (`[[\d+]]`) avoids the doubling.

## Match

Functions that find matches return `Match` tables:

```luau
type Match = {
    text: string,               -- the matched text
    start: number,              -- 1-based position of the first character
    stop: number,               -- 1-based position of the last character (inclusive)
    groups: { string | false }, -- capture groups; false for groups that didn't participate
}
```

`start` and `stop` follow Luau's `string.sub` convention: `text:sub(m.start, m.stop) == m.text`.

## regex.test

```luau
regex.test(text: string, pattern: string, flags: string?): boolean
```

Whether the pattern matches anywhere in `text`.

## regex.matches

```luau
regex.matches(text: string, pattern: string, flags: string?): boolean
```

Whether the pattern matches the **whole** of `text`.

## regex.find

```luau
regex.find(text: string, pattern: string, flags: string?, init: number?): Match?
```

The first match at or after position `init` (1-based, default 1), or `nil`.

```luau
local m = regex.find("key = value", "(\\w+)\\s*=\\s*(\\w+)")
print(m.groups[1], m.groups[2]) --> key   value
```

## regex.findAll

```luau
regex.findAll(text: string, pattern: string, flags: string?): { Match }
```

Every non-overlapping match.

## regex.replace

```luau
regex.replace(text: string, pattern: string, repl: string, flags: string?, limit: number?): (string, number)
```

Replaces matches and returns the new text and the number of replacements. `limit` caps the
number of replacements; a negative limit (the default) replaces all. In `repl`:

| Token | Inserts |
|---|---|
| `$1` ... `$99` | A capture group. |
| `$&` | The whole match. |
| `` $` `` | The text before the match. |
| `$'` | The text after the match. |
| `$$` | A literal `$`. |

```luau
regex.replace("John Smith", "(\\w+) (\\w+)", "$2, $1") --> "Smith, John", 1
```

## regex.split

```luau
regex.split(text: string, pattern: string, flags: string?): { string }
```

Splits `text` on every match. Empty matches are ignored.

```luau
regex.split("a, b;c", "[,;]\\s*") --> { "a", "b", "c" }
```

## regex.filter

```luau
regex.filter(list: { string }, pattern: string, flags: string?, invert: boolean?): { string }
```

Keeps the strings that match, or with `invert`, the ones that don't.

```luau
regex.filter({ "a.lua", "b.txt" }, "\\.lua$") --> { "a.lua" }
```

## regex.escape

```luau
regex.escape(text: string): string
```

Escapes every special character, so `text` matches literally.

## regex.isValid

```luau
regex.isValid(pattern: string, flags: string?): (boolean, string?)
```

Whether the pattern compiles. On failure, also returns the error message.

## regex.patterns

Ready-made patterns, all anchored to match a whole string:

| Name | Matches |
|---|---|
| `email` | A simple e-mail address. |
| `integer` | An optionally signed integer. |
| `number` | A decimal number, with optional exponent. |
| `identifier` | A C-style identifier. |
| `uuid` | A UUID, any case. |
| `ipv4` | A dotted IPv4 address. |
| `hex` | Hex digits, optionally prefixed with `0x`. |

```luau
regex.test("ada@example.com", regex.patterns.email) --> true
```
