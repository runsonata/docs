# <code><a href="../../namespaces/sonata">sonata</a>::<a href="../../namespaces/luau">luau</a>::DataValue</code> (Class)

A small value tree for a **literal** Luau value: `nil`, `true`/`false`, numbers, strings, and
nested tables built out of those. Nothing that requires running Luau code.

`#include <sonata/core/luau/datafile.hpp>`

It is produced by [`DataFile::parse`](luau_datafile.md#parse), but you can also build one by hand
with `table()`, `array()`, `set()` and `push()`, to write it back out with
[`DataFile::serialize`](luau_datafile.md#serialize) or `save`. Nothing about it is
project-specific.

## Kinds

```cpp
enum class Kind { Nil, Boolean, Number, String, Table };
```

## Construction

| Constructor / factory | Produces |
|---|---|
| `DataValue()` | `nil` |
| `DataValue(bool)` | a boolean |
| `DataValue(double)` | a number |
| `DataValue(std::string)`, `DataValue(const char*)` | a string |
| `DataValue(Entries)` | a table with these entries |
| `static DataValue table()` | an empty table, ready for `set()`/`push()` |
| `static DataValue array(std::vector<DataValue>)` | a table of positional entries: `{ v1, v2, ... }` |

## Inspecting

| Method | Description |
|---|---|
| `kind()` | The `Kind`. |
| `isNil()`, `isBoolean()`, `isNumber()`, `isString()`, `isTable()` | Kind checks. |
| `isArray()` | True for a table whose entries are all positional, e.g. `{1, 2, 3}`. |
| `asBoolean()`, `asNumber()`, `asString()`, `asTable()` | The value. Each throws `std::bad_variant_access` if the kind doesn't match. |
| `items()` | Just the positional (array-part) values, in order. |
| `find(key)` | The entry with string key `key` (`foo = ...` or `["foo"] = ...`), or `nullptr` if this isn't a table or has no such key. |

## Modifying

| Method | Description |
|---|---|
| `DataValue& set(std::string key, DataValue value)` | Sets a named entry (replacing an existing one). Tables only; throws `std::logic_error` otherwise. |
| `DataValue& push(DataValue value)` | Appends a positional entry. Tables only. |
| `std::string serialize() const` | Luau source for just this value, without a leading `return`. |

## Entries and keys

```cpp
struct Key {
    enum class Kind { String, Number } kind;
    std::string string;
    double number = 0.0;

    static Key ofString(std::string value);
    static Key ofNumber(double value);
};

struct Entry {
    std::optional<Key> key; // unset for positional entries
    DataValue value;
};

using Entries = std::vector<Entry>;
```

A table is an ordered list of entries. `key` is set for named or indexed entries
(`foo = 1`, `["foo"] = 1`, `[1] = "x"`) and unset for plain positional ones (`{1, 2, 3}`), so a
table read from a file serializes back in its original order.

```cpp
for (const auto& entry : value.asTable()) {
    if (entry.key && entry.key->kind == DataValue::Key::Kind::String)
        std::cout << entry.key->string << " = " << entry.value.serialize() << '\n';
}
```
