# <code><a href="../sonata">sonata</a>::text</code> (namespace)

Small string helpers shared by every layer.

`#include <sonata/base/text.hpp>`

```cpp
std::size_t editDistance(std::string_view a, std::string_view b);
std::optional<std::string> closestMatch(std::string_view input, const std::vector<std::string>& candidates);
std::string join(const std::vector<std::string>& items, std::string_view separator);
std::vector<std::string> splitList(std::string_view text);
std::string jsonString(std::string_view text);
std::string humanSize(std::uintmax_t bytes);
```

| Function | Description |
|---|---|
| `editDistance(a, b)` | The edit distance between two strings. |
| `closestMatch(input, candidates)` | The candidate closest to `input`, if any is close enough to be a typo. This is what "did you mean" suggestions use. |
| `join(items, separator)` | The items with `separator` between them. |
| `splitList(text)` | Splits on commas, trimming blanks and dropping empty items: `"a, b,,c"` gives `a`, `b`, `c`. |
| `jsonString(text)` | `text` as a JSON string, quotes included. |
| `humanSize(bytes)` | `"2.1 GiB"`, `"1.5 MiB"`, `"12.0 KiB"`, `"512 B"`. |
