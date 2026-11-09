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
| An IANA zone name | `"Europe/Paris"`, `"America/New_York"` |
| `"local"`: the machine's zone (see [below](#the-local-zone)) | `"local"` |
| A POSIX TZ string (**west** is positive) | `"CET-1CEST,M3.5.0,M10.5.0/3"`, `"<+03>-3"` |

IANA zones carry their **whole history**: Istanbul was on +02:00 with summer time in 2010 and is
on +03:00 all year now, and both come out right. The data is IANA's time zone database,
built into `sn` ([`datetime.tzdata`](#datetimezones-datetimetzdata) says which release), so it
is the same on every machine and needs nothing installed. There are no leap seconds.

A local time in a DST gap moves forward by the gap; an ambiguous one picks the earlier instant.
Names are case-sensitive, and a misspelled one raises with a suggestion.

```luau
datetime.format(1278000000, "%F %T %Z", "Europe/Istanbul") --> "2010-07-01 19:00:00 EEST"
datetime.format(1782900000, "%F %T %Z", "Europe/Istanbul") --> "2026-07-01 13:00:00 +03"
```

### The local zone

The **default zone is UTC**, so a program gives the same answers wherever it runs. For the
machine's own time, pass `"local"`:

```luau
print(datetime.format(datetime.now(), "%H:%M %Z", "local")) --> "21:04 CEST"
print(datetime.localZone())                                  --> "Europe/Paris"
```

`"local"` is what the `TZ` environment variable says, if it's set: a zone name (`Asia/Tokyo` or
`:Asia/Tokyo`), a path to a zone file, or a POSIX TZ string. An empty `TZ` means UTC. Without
`TZ`, it's the system's setting: the `/etc/localtime` link on Linux, macOS and BSD, the zone
setting on Android, and on Windows its zone, translated to the IANA name. If none of these says
anything usable, it's UTC. A change to `TZ` (through `process.env`) is picked up straight away.

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

## datetime.diff

```luau
datetime.diff(from: number, to: number, units: (string | { string })?, zone: Zone?,
              fromNsec: number?, toNsec: number?): Delta
```

How far `to` is from `from`. `units` is one unit or a list of them: `"year"`, `"month"`,
`"week"`, `"day"`, `"hour"`, `"minute"`, `"second"` and `"nsec"` (default: all of them but
`"week"`). The result is a [`Delta`](#datetimeadd) with a field for every unit asked for: the
largest number of each that fits, largest first, with whatever is left below the smallest unit
dropped. If `to` is earlier than `from`, every field is negative or zero.

Calendar units are counted on the wall clock in `zone`, the way [`datetime.add`](#datetimeadd)
moves it, so adding the result back gives `to` exactly: `add(from, diff(from, to, nil, zone), zone)`
is `to`. A day is a calendar day, even the 23-hour one when DST starts, and January 31 to
February 28 is one month.

```luau
local born = datetime.fromFields({ year = 1990, month = 5, day = 17 }, "local")
print(datetime.diff(born, (datetime.now()), "year", "local").years)   --> 36

local d = datetime.diff(start, finish)
print(d.days, d.hours, d.minutes)                                      --> 1  2  30

print(datetime.diff(start, finish, "hour").hours)                      --> 26
```

## Durations

### datetime.parseDuration

```luau
datetime.parseDuration(text: string): (Delta?, string?)
```

Reads an ISO 8601 duration such as `"P1Y2M3DT4H5M6.5S"` into a delta, with a field for each part
the text gives. A leading `-` makes every part negative, and `W` gives weeks. Hours, minutes and
seconds may have a fraction (with `.` or `,`), and a fraction of a second becomes `nsec`,
exactly. Anything else returns `nil` and what's wrong with it.

```luau
local delta = assert(datetime.parseDuration("PT1H30M"))  --> { hours = 1, minutes = 30 }
local later = datetime.add(datetime.now(), delta)
```

### datetime.formatDuration

```luau
datetime.formatDuration(delta: Delta): string
```

Writes a delta as an ISO 8601 duration: `{ days = 1, hours = 2 }` gives `"P1DT2H"`, and an empty
one gives `"PT0S"`. ISO 8601 has a sign for the whole duration only, so every part has to be
positive, or every part negative.

## datetime.relative

```luau
datetime.relative(t: number, now: number?): string
```

How long ago `t` was, or how far off it is, in English: `"just now"`, `"5 minutes ago"`,
`"in 3 days"`. The unit is the largest one that is at least 1 (seconds, minutes, hours, days,
weeks, months of 30.436875 days, years of 365.2425 days), rounded down. `now` defaults to the
current time.

```luau
print(datetime.relative(entry.created))    --> "3 hours ago"
```

Functions that give an instant also give its nanoseconds, so wrap them in parentheses to pass
only the instant: `datetime.relative((datetime.parse(text)))`.

## datetime.zones / datetime.tzdata

```luau
datetime.zones(): { string }
datetime.tzdata: string
```

Every IANA zone name, sorted (about 600, including old names such as `"US/Eastern"`), and the
release of the database they come from, such as `"2026e"`.

## datetime.localZone

```luau
datetime.localZone(): string
```

The name of the zone `"local"` means, as described [above](#the-local-zone): an IANA name, the
POSIX TZ string `TZ` gave, or `"UTC"`.

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
