# <code><a href="../../namespaces/sonata">sonata</a>::<a href="../../namespaces/luau">luau</a>::DataFile</code> (Class)

Reads and writes `.luau` files whose entire body is `return <table>`: "config as Luau" files such
as `.sonata/project.luau` and `.sonata/lock.luau`.

`#include <sonata/core/luau/datafile.hpp>`

It parses with Luau's own front end (the same parser the compiler uses) and never creates a
`lua_State`, so it can't run arbitrary code: only literal values and table constructors are
accepted. The result is a [`DataValue`](luau_datavalue.md) tree.

## Definition

```cpp
class DataFile {
public:
    static DataValue parse(const std::string& source, const std::string& chunkName = "=data");
    static DataValue parseFile(const std::filesystem::path& path);
    static std::vector<std::string> directives(const std::string& source);
    static std::string serialize(const DataValue& value);
    static void save(const DataValue& value, const std::filesystem::path& path);
};
```

## Methods

### `parse`

```cpp
static DataValue parse(const std::string& source, const std::string& chunkName = "=data");
```

Parses `source`. Throws [`DataFileError`](#datafileerror) if it isn't exactly
`return <table constructor>`, or if the table contains anything beyond literal `nil`, boolean,
number and string values and nested tables (variables, calls, operators other than a unary `-`
on a number, ...). `chunkName` is only used in error messages. Comments are fine.

### `parseFile`

```cpp
static DataValue parseFile(const std::filesystem::path& path);
```

Reads and parses a file.

### `directives`

```cpp
static std::vector<std::string> directives(const std::string& source);
```

The `--!name` directives at the top of `source`, before any code: `{ "strict" }` for a file
starting with `--!strict`. Only the names are returned. Never throws for a syntax error; the
directives that could be read are returned.

### `serialize`

```cpp
static std::string serialize(const DataValue& value);
```

`value` must be a table. Produces `"return { ... }\n"`, indented with four spaces.

### `save`

```cpp
static void save(const DataValue& value, const std::filesystem::path& path);
```

Serializes `value` and writes it to `path`.

## `DataFileError`

```cpp
class DataFileError : public std::runtime_error;
```

Thrown by `parse` and `parseFile`.

## Example

```cpp
using namespace sonata::luau;

DataValue config = DataFile::parse(R"(
    return {
        name = "demo",
        ports = { 80, 443 },
        debug = false,
    }
)");

if (const DataValue* name = config.find("name"); name && name->isString())
    std::cout << name->asString() << '\n';

for (const DataValue& port : config.find("ports")->items())
    std::cout << port.asNumber() << '\n';

DataValue out = DataValue::table();
out.set("version", 1.0);
out.set("tags", DataValue::array({"a", "b"}));
DataFile::save(out, "out.luau");
// return {
//     version = 1,
//     tags = {
//         "a",
//         "b",
//     },
// }
```
