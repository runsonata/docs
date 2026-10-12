# @sonata/datetime

Dates, times and time zones, precise to the nanosecond.

```luau
local datetime = require("@sonata/datetime")

local t = 1791831891
print(datetime.format(t))                                     --> "2026-10-12T19:04:51Z"
print(datetime.format(t, "%A %-d %B, %H:%M", "Europe/Paris")) --> "Monday 12 October, 21:04"

local now, nsec = datetime.now()
```

## Concepts

### Instants

An instant is a **number of Unix seconds** (fractions allowed). A double only keeps about 0.2
microseconds of precision near today, so every function that *produces* an instant also returns
a second value: its exact nanosecond part (0 to 999999999).

To stay exact, pass that value back as the **last argument** (`nsec`) of the functions that
accept one. When `nsec` is given, the fractional part of `t` is ignored.

```luau
local t, nsec = datetime.now()
print(datetime.format(t, "%T.%N", "UTC", nsec)) --> "19:04:51.123456789"
```

### Zones

Wherever a `zone` is accepted (default UTC), it can be:

| Form | Example |
|---|---|
| A number: a fixed offset in seconds **east** of UTC | `19800` |
| A fixed offset string (ISO sign: east is positive) | `"UTC"`, `"Z"`, `"+05:30"`, `"-0800"`, `"UTC+2"` |
| An IANA zone name from the built-in table | `"Europe/Paris"`, `"America/New_York"` |
| A POSIX TZ string (**west** is positive) | `"EST5EDT,M3.2.0,M11.1.0"`, `"<+03>-3"` |

Only the **current** rules of each zone are modeled: there are no historical transitions and no
leap seconds. A local time in a DST gap moves forward by the gap; an ambiguous one picks the
earlier instant.

### Fields

```luau
type Fields = {
    year: number, month: number, day: number,
    hour: number, min: number, sec: number, nsec: number,
    wday: number,     -- day of the week, 1 = Sunday
    yday: number,     -- day of the year, 1-based
    isoYear: number, isoWeek: number,
    offset: number,   -- seconds east of UTC
    isdst: boolean,
    abbr: string,     -- zone abbreviation, e.g. "CEST"
}
```

## datetime.now

```luau
datetime.now(): (number, number)
```

The current time: `t, nsec`.

## datetime.monotonic

```luau
datetime.monotonic(): number
```

Seconds on a monotonic clock. Only meaningful for measuring durations.

## datetime.toFields

```luau
datetime.toFields(t: number, zone: Zone?, nsec: number?): Fields
```

Splits an instant into calendar fields in `zone`.

```luau
local f = datetime.toFields(datetime.now(), "Asia/Tokyo")
print(f.year, f.month, f.day, f.hour)
```

## datetime.fromFields

```luau
datetime.fromFields(fields: { [string]: number }, zone: Zone?): (number, number)
```

Builds an instant from calendar fields interpreted in `zone`. Missing fields default to
1970-01-01 00:00:00. Out-of-range values roll over: month 13 is January of the next year, day 0
is the last day of the previous month.

```luau
local t = datetime.fromFields({ year = 2026, month = 12, day = 25, hour = 9 }, "Europe/London")
```

## datetime.parse

```luau
datetime.parse(text: string, format: string?, zone: Zone?): (number?, number | string)
```

Parses `text` and returns `t, nsec`, or `nil, error`. `format` is a [format string](#format-tokens)
or a [preset](#presets); the default, `"iso"`, auto-detects ISO 8601, RFC 3339, RFC 2822 and
HTTP dates. `zone` applies when the text carries no offset.

```luau
local t = datetime.parse("2026-10-12T21:04:51+02:00")
local t2 = datetime.parse("12/10/2026 21:04", "%d/%m/%Y %H:%M", "Europe/Paris")
```

## datetime.format

```luau
datetime.format(t: number, format: string?, zone: Zone?, nsec: number?): string
```

Formats an instant. `format` is a format string or a preset (default `"iso"`).

## datetime.add

```luau
datetime.add(t: number, delta: Delta, zone: Zone?, nsec: number?): (number, number)

type Delta = {
    years: number?, months: number?, weeks: number?, days: number?,
    hours: number?, minutes: number?, seconds: number?, nsec: number?,
}
```

Adds a duration. **Calendar units** (`years`, `months`, `weeks`, `days`) move the local
wall-clock time in `zone`, so they are DST-safe, and the day is clamped (January 31 + 1 month is
February 28 or 29). **Exact units** (`hours`, `minutes`, `seconds`, fractions allowed, and
`nsec`) move the instant itself. Negative values go backwards.

```luau
local tomorrow = datetime.add(datetime.now(), { days = 1 }, "Europe/Paris")
local later = datetime.add(datetime.now(), { hours = 1, minutes = 30 })
```

## datetime.startOf

```luau
datetime.startOf(t: number, unit: string, zone: Zone?, nsec: number?): (number, number)
```

Rounds an instant down to the start of a `"year"`, `"month"`, `"week"` (Monday), `"day"`,
`"hour"`, `"minute"` or `"second"` in `zone`.

## datetime.convert

```luau
datetime.convert(value: number, from: string, to: string): number
```

Converts a timestamp between scales:

| Scale | Meaning |
|---|---|
| `unix` | Seconds since 1970-01-01 UTC. |
| `unixms`, `unixus` | Milliseconds / microseconds since 1970-01-01 UTC. |
| `julian` | Julian Day. |
| `mjd` | Modified Julian Day. |
| `excel` | Excel serial date (days since 1899-12-30). |
| `filetime` | Windows FILETIME (100 ns ticks since 1601-01-01). |
| `dotnet` | .NET ticks (100 ns since 0001-01-01). |
| `ntp` | NTP seconds (since 1900-01-01). |
| `cocoa` | Apple Cocoa / Core Data seconds (since 2001-01-01). |

```luau
datetime.convert(1700000000000, "unixms", "unix") --> 1700000000
```

## datetime.isLeapYear

```luau
datetime.isLeapYear(year: number): boolean
```

## datetime.daysInMonth

```luau
datetime.daysInMonth(year: number, month: number): number
```

## Format tokens

`format` and `parse` accept the same tokens, except the output-only ones.

| Token | Meaning |
|---|---|
| `%Y` `%y` | Year, 4 / 2 digits. |
| `%m` `%d` `%e` | Month, day (zero / space padded). |
| `%H` `%I` `%M` `%S` `%p` | Hour (24 / 12), minute, second, AM/PM. |
| `%j` | Day of the year. |
| `%a` `%A` `%b` `%B` `%h` | Weekday and month names, short and long (`%h` = `%b`). |
| `%u` `%w` | Weekday: 1–7 with Monday = 1 / 0–6 with Sunday = 0. |
| `%V` `%G` | ISO week number / ISO week year. |
| `%s` | Unix seconds. |
| `%N` `%3N` `%6N` `%L` | Fraction of a second: 9 digits, 3, 6, 3. |
| `%f` | `".123"`: fraction with trailing zeros trimmed, empty if zero. |
| `%z` `%:z` `%::z` | Offset: `+0530`, `+05:30`, `+05:30:15`. |
| `%Z` | Zone abbreviation. |
| `%F` `%T` `%D` `%R` `%c` | Composites: `%Y-%m-%d`, `%H:%M:%S`, `%m/%d/%y`, `%H:%M`, `%a %b %e %T %Y`. |
| `%n` `%t` `%%` | Newline, tab, `%`. |

Put `-` after `%` to drop padding: `%-d` gives `5` instead of `05`.

## Presets

Instead of a format string, pass one of these names:

| Preset | Example |
|---|---|
| `"iso"` (default) | `2026-10-12T19:04:51Z`, or `2026-10-12T21:04:51.5+02:00` (RFC 3339; the fraction is printed only if non-zero, trailing zeros trimmed). For `parse`, auto-detects ISO 8601, RFC 3339, RFC 2822 and HTTP dates. |
| `"rfc2822"` | `Mon, 12 Oct 2026 19:04:51 +0000` |
| `"http"` | `Mon, 12 Oct 2026 19:04:51 GMT` (use zone UTC) |
| `"date"` | `2026-10-12` |
| `"time"` | `19:04:51` |
| `"ctime"` | `Mon Oct 12 19:04:51 2026` |
