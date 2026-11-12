# @sonata/net

An HTTP client, and the building blocks under it: sockets, TLS, DNS, IP addresses, URLs, and the
wire formats of HTTP/1.1 and WebSocket, for writing other protocols (or another HTTP client or
server) in plain Luau.

```luau
local net = require("@sonata/net")

local res = assert(net.request("https://example.com/"))
print(res.status, res.headers["content-type"]) --> 200  text/html
```

**Errors:** failures that depend on the outside world (connection refused, timeouts, DNS
errors, ...) **don't raise**: the call returns `nil, message`. Only misuse (wrong argument
types, using a closed socket) raises. Wrap calls in `assert` when a failure should stop the
program.

**Waiting:** requests, connecting, reading, accepting, DNS lookups and TLS handshakes never block
other [tasks](task.md). Outside a task, they wait right there. Sockets close themselves when
garbage collected.

## HTTP client

### net.request

```luau
net.request(url: string, options: RequestOptions?): (Response?, string?)

type RequestOptions = {
    method: string?,                 -- default "GET"
    headers: Headers?,               -- { name = value | { value } } or { { name, value } }
    query: (string | table)?,        -- added to the URL's query
    body: (string | buffer | (() -> string?) | Reader)?,
    form: table?,                    -- application/x-www-form-urlencoded
    multipart: { Part }?,            -- multipart/form-data
    timeout: number?,                -- seconds, default 30
    redirects: (number | false)?,    -- default 10
    decompress: boolean?,            -- default true
    keepAlive: boolean?,             -- default true
    maxSize: number?,                -- bytes, default 256 MiB
    stream: boolean?,                -- default false
    tls: (TlsOptions | TlsContext)?,
    proxy: (string | ProxyOptions)?,
    unix: string?,
}
```

Makes an HTTP/1.1 request and reads the response. A status other than 2xx is still a response,
with `ok` set to `false`. Only failing to get a response at all (the connection is refused, the
certificate is wrong, the server times out, ...) returns `nil, message`.

```luau
local json = require("@sonata/json")

local res = assert(net.request("https://api.github.com/repos/luau-lang/luau", {
    headers = { accept = "application/vnd.github+json" },
}))
if res.ok then
    print(json.decode(res.body).stargazers_count)
else
    print("GitHub said " .. res.status .. " " .. res.reason)
end
```

**Headers.** `Host`, `User-Agent` (`sonata/<version>`), `Accept` (`*/*`) and `Accept-Encoding`
are sent unless `headers` has its own. Credentials in the URL (`https://user:pass@host/`) are
sent as Basic authentication, and kept for redirects within the same origin.

**Bodies.** Give one of `body`, `form` (a table, as for [`net.url.buildQuery`](#other-url-functions))
or `multipart` (parts, as for [`net.http.encodeMultipart`](#multipart)). The last two also set
`Content-Type`. A string or buffer body is sent with its length. A function body is called for
the next piece until it returns `nil`, and a [reader](stream.md#readers-and-writers) is read
until it ends; both are sent chunked unless `headers` gives a `Content-Length`:

```luau
local fs = require("@sonata/fs")

local file = fs.open("backup.tar")
local res = assert(net.request("https://example.com/upload", {
    method = "PUT",
    body = file,
}))
file:close()
```

A streamed response is a reader too, so it can be the body of the next request.

**Redirects** are followed, up to `redirects` of them. A 303, and a 301 or 302 answering a POST,
turn the request into a GET without a body, the way browsers do. `Authorization` and `Cookie`
aren't sent on to another origin. With `redirects = false`, the redirect itself is returned. A
redirect that would need a function body again isn't followed either, since that body has been
used up.

**Timeouts.** `timeout` is how long the server may keep the request waiting at any one point:
connecting, sending, or between two pieces of the response. `math.huge` waits forever. To limit
the whole request, wrap it in [`task.timeout`](task.md).

**Compression.** `gzip`, `deflate` and `zstd` responses are decompressed; `res.headers` still
shows what was sent. Other codings are left as they came. `decompress = false` neither asks for
compression nor undoes it.

**Connections** are kept open and reused for later requests to the same origin, made the same
way: requests with their own `tls` options or a `proxy` table get connections of their own. An
idle connection the server has closed is noticed and replaced, and a GET (or another idempotent
method) is sent again if a reused connection dies before answering. `keepAlive = false` sends
`Connection: close` and keeps nothing.

**HTTPS** checks the server's certificate against the system's root certificates (see [TLS](#tls)).
`tls` takes the same options as [`net.connect`](#netconnect), or a [context](#nettlscontext).

**Proxies and Unix sockets.** `proxy` is as for [`net.connect`](#netconnect); an HTTP proxy is
asked for a tunnel (`CONNECT`), for `http` URLs too. `unix` connects to a Unix domain socket
instead of the URL's host, which still gives the `Host` header:

```luau
local res = assert(net.request("http://localhost/v1.43/containers/json", { unix = "/var/run/docker.sock" }))
```

### Response

| Field | Type | Description |
|---|---|---|
| `ok` | `boolean` | `status` is 200–299. |
| `status`, `reason`, `version` | `number`, `string`, `string` | `200`, `"OK"`, `"1.1"` |
| `headers` | `{ [string]: string }` | Lower-case names, repeated headers joined by `", "` (`set-cookie` by `"\n"`). |
| `headerList` | `{ { string } }` | `{ { name, value } }` exactly as received. |
| `body` | `string` | The whole body, decompressed. `""` with `stream`. |
| `url` | `string` | The URL that answered, after redirects, without credentials. |
| `socket` | `Socket?` | After `101 Switching Protocols`: the connection, now speaking the new protocol. |
| `res:read()` | `string?` | The next piece of the body, `nil` at the end, or `nil, err`. Without `stream`, the whole body once. |
| `res:close()` | | Gives up on the rest of a streamed body, and closes its connection. |

A body larger than `maxSize` (at most 1 GiB - 1, the longest string Luau allows) fails the
request. For anything bigger, or to start on a body before all of it has arrived, set
`stream = true` and read it in pieces:

```luau
local res = assert(net.request("https://example.com/big.iso", { stream = true }))
while true do
    local piece, err = res:read()
    if piece == nil then
        assert(err == nil, err)
        break
    end
    fs.appendFile("big.iso", piece)
end
```

## Sockets

### net.connect

```luau
net.connect(host: string, port: number, options: (number | ConnectOptions)?): (Socket?, string?)

type ConnectOptions = {
    timeout: number?,                       -- seconds
    family: ("any" | "ipv4" | "ipv6")?,
    nodelay: boolean?,                      -- disable Nagle's algorithm
    localAddress: string?, localPort: number?,
    tls: (boolean | TlsOptions | TlsContext)?, -- TLS handshake right after connecting
    proxy: (string | ProxyOptions)?,
}
```

Opens a TCP connection. `options` may be just a timeout. The timeout applies to the
connection, and then to every later wait on the socket.

`proxy` is a URL (`"socks5://user:pass@host:1080"`, `"http://host:3128"`) or a table
`{ type, host, port, username, password }`.

### net.listen

```luau
net.listen(host: string?, port: number, options: (number | ListenOptions)?): (Socket?, string?)

type ListenOptions = {
    backlog: number?,
    reuseAddress: boolean?,
    reusePort: boolean?,
    ipv6Only: boolean?,
    family: ("any" | "ipv4" | "ipv6")?,
}
```

Opens a TCP server. `host = nil` listens on all interfaces; `port = 0` picks a free port (read
it back with `sock:localAddress()`). `options` may be just a backlog.

```luau
local task = require("@sonata/task")

local server = assert(net.listen(nil, 8080))
while true do
    local client = server:accept()
    if client then
        task.spawn(function()
            local line = client:recvLine()
            client:send("you said: " .. tostring(line) .. "\n")
            client:close()
        end)
    end
end
```

### net.udp

```luau
net.udp(host: string?, port: number?, options: (boolean | UdpOptions)?): (Socket?, string?)

type UdpOptions = { reuse: boolean?, reusePort: boolean?, broadcast: boolean?, family: string? }
```

Opens a UDP socket, bound if `host` or `port` is given. `options` may be just `reuse`.

### net.raw

```luau
net.raw(protocol: string | number, family: ("ipv4" | "ipv6")?): (Socket?, string?)
```

Opens a raw IP socket for `"icmp"`, `"icmpv6"`, `"tcp"`, `"udp"` or a protocol number 0–255.
Needs administrator rights (root or `CAP_NET_RAW` on Linux).

### net.unix.connect / net.unix.listen

```luau
net.unix.connect(path: string, timeout: number?): (Socket?, string?)
net.unix.listen(path: string, backlog: number?): (Socket?, string?)
```

Unix domain sockets. `listen` replaces a stale socket file, and removes the file when the server
closes.

### net.select

```luau
net.select(readers: { Socket }, writers: { Socket }?, timeout: number?): ({ Socket }, { Socket })
```

Waits until some of the sockets are ready, and returns those ready to read and those ready to
write.

### Socket methods

`send`, `sendTo` and `unread` take a string or a `buffer`.

| Method | Returns | Description |
|---|---|---|
| `sock:send(data)` | `bytesSent` | Sends everything, or returns `nil, err, bytesSentSoFar`. |
| `sock:write(data)` | | Like `send`, but raises instead of returning an error. With `read`, makes a socket a [stream](stream.md) reader and writer. |
| `sock:read(max?)` | `string?` | What has arrived, up to `max` bytes (default 64 KiB); `nil` once the peer has closed the connection. Errors and timeouts raise. |
| `sock:recv(max?, exact?)` | `string` | Up to `max` bytes (default 4096). With `exact`, waits for all of them. `""` means the peer closed the connection. |
| `sock:recvUntil(delim, max?)` | `string` | Everything up to and including `delim` (`max` defaults to 1 MiB). |
| `sock:recvLine(max?)` | `string` | One line, without `"\n"` or `"\r\n"`. The last line may lack one. |
| `sock:recvAll(max?)` | `string` | Everything until the peer closes. |
| `sock:unread(data)` | | Puts `data` back in front of what `recv` returns next. |
| `sock:buffered()` | `number` | Bytes received but not read yet. |
| `sock:accept(timeout?)` | `Socket` | Accepts a connection (server sockets). |
| `sock:sendTo(data, host, port?)` | `bytesSent` | UDP, or raw (no port). |
| `sock:recvFrom(max?)` | `data, host, port` | UDP or raw (`max` defaults to 2048). |
| `sock:startTls(options?)` | `true` | Upgrades to TLS: as a client, or as a server on an accepted socket. Refuses if unread data is buffered. |
| `sock:tlsInfo()` | `{ version, cipher, alpn?, serverName? }?` | Details of the TLS session, or `nil`. |
| `sock:peerCertificate()` | `Certificate?` | The peer's certificate (see below), or `nil`. |
| `sock:joinGroup(group, iface?)`, `sock:leaveGroup(group, iface?)` | | Multicast membership. |
| `sock:setMulticastInterface(iface)` | | |
| `sock:shutdown(how?)` | `true` | `"write"` (default), `"read"` or `"both"`. |
| `sock:setTimeout(seconds?)` | | Timeout for every later wait; `nil` waits forever (the default). |
| `sock:getTimeout()` | `number?` | |
| `sock:setOption(name, value)`, `sock:getOption(name)` | | See below. |
| `sock:localAddress()`, `sock:peerAddress()` | `host, port` | |
| `sock:kind()` | `string` | `"tcp"`, `"udp"`, `"raw"` or `"unix"`. |
| `sock:close()`, `sock:isClosed()` | | |

Options for `setOption`/`getOption`:

| Kind | Names |
|---|---|
| booleans | `"nodelay"` `"keepalive"` `"broadcast"` `"reuseAddress"` `"hdrincl"` `"multicastLoop"` |
| numbers | `"recvBufferSize"` `"sendBufferSize"` `"ttl"` `"multicastTtl"` |
| `"linger"` | seconds, or `false` |

`Certificate` is
`{ subject, issuer, serial, notBefore, notAfter, fingerprint (SHA-256 hex), altNames }`.

One task reading and another writing the same socket at the same time is fine. Two tasks reading
the same socket get the data in whatever order they happen to run.

## TLS

TLS uses Mbed TLS, which is built into `sn`, and supports TLS 1.2 and 1.3. A program can leave
it out ([`build.without`](../../guide/building.md#leaving-features-out) `"tls"`): then
`net.tls.available` is `false`, and every TLS connection, `https` included, fails with an error
that says TLS isn't in this program. Plain sockets and `http` work the same.

Clients trust the system's root certificates, which are read from the Windows certificate store,
or from the usual bundle locations on Linux, macOS and Android. If yours are somewhere else, set
`SSL_CERT_FILE` or `SSL_CERT_DIR`, or pass `caFile` or `caPem`. [`sn doctor`](../../guide/doctor.md)
shows which ones were found.

```luau
type TlsOptions = {
    host: string?,          -- name for SNI and verification (default: the host given to connect)
    verify: boolean?,       -- default true
    caFile: string?, caPem: string?,     -- trusted CAs (default: the system's trust store)
    cert: string?, certPem: string?,     -- our certificate: servers, or clients for mutual TLS
    key: string?, keyPem: string?,       -- its private key
    alpn: { string }?,      -- e.g. { "h2", "http/1.1" }
    minVersion: ("1.2" | "1.3")?,
    server: boolean?,       -- contexts only: a server context
    verifyClient: boolean?, -- servers: require a client certificate
    context: TlsContext?,
}
```

Pass `TlsOptions` as the `tls` option of `net.connect`, or to `sock:startTls`.

!!! danger

    `verify = false` disables **all** certificate checks. Use it for testing only.

### net.tls.context

```luau
net.tls.context(options: TlsOptions): (TlsContext?, string?)
```

A TLS configuration loaded once and shared by many connections. Servers should use one. Pass it
as the `tls` option or to `startTls`.

```luau
local ctx = net.tls.context({ server = true, cert = "cert.pem", key = "key.pem" })
local server = assert(net.listen(nil, 8443))
local client = server:accept()
assert(client:startTls({ context = ctx }))
```

### net.tls.available / net.tls.library

`net.tls.available` is `true` when this program has TLS, and `net.tls.library` names the TLS
library (`"Mbed TLS 3.6.7"`); it's `nil` without TLS.

Mid-stream upgrades (SMTP/IMAP `STARTTLS`) work with `sock:startTls`.

## DNS

Every lookup runs on a worker thread, so it never blocks other tasks.

### net.dns.resolve / net.resolve

```luau
net.dns.resolve(host: string, family: ("any" | "ipv4" | "ipv6")?): ({ string }?, string?)
```

The addresses of `host`, through the system resolver: `{ "93.184.216.34", "2606:2800:..." }`.
`net.resolve` is the same function.

### net.dns.reverse

```luau
net.dns.reverse(address: string): (string?, string?)
```

The host name of an address.

### net.dns.query

```luau
net.dns.query(name: string, type: (string | number)?, options: QueryOptions?): ({ DnsRecord }?, string?)

type QueryOptions = {
    server: (string | { string })?, -- "1.1.1.1", "[::1]:53" or a list (default: the system's)
    timeout: number?,               -- seconds (default 5)
    tcp: boolean?,                  -- use TCP (default false)
}
```

Asks a DNS server directly, for record types the system resolver can't look up. `type` is
`"A"` (default), `"AAAA"`, `"CNAME"`, `"MX"`, `"NS"`, `"PTR"`, `"SOA"`, `"SRV"`, `"TXT"`,
`"CAA"`, `"HTTPS"`, ... or a number.

Each `Record` has `name`, `type` and `ttl`, plus:

| Type | Fields |
|---|---|
| A, AAAA | `address` |
| CNAME, NS, PTR | `target` |
| MX | `priority`, `exchange` |
| TXT | `text` (joined), `strings` |
| SRV | `priority`, `weight`, `port`, `target` |
| SOA | `mname`, `rname`, `serial`, `refresh`, `retry`, `expire`, `minimum` |
| CAA | `flags`, `tag`, `value` |
| others | `data` (raw bytes) |

```luau
for _, mx in assert(net.dns.query("gmail.com", "MX")) do
    print(mx.priority, mx.exchange)
end
```

### net.dns.servers

```luau
net.dns.servers(): { string }
```

The system's DNS servers.

## IP addresses

| Function | Returns |
|---|---|
| `net.ip.isValid(text)` | `boolean` |
| `net.ip.version(text)` | `4`, `6` or `nil` |
| `net.ip.parse(text)` | `{ version, bytes, zone? }` |
| `net.ip.normalize(text)` | The canonical form: `"::1"`, `"2001:db8::1"`. |
| `net.ip.fromBytes(bytes)` | The text form of 4 or 16 raw bytes. |
| `net.ip.kind(text)` | `"public"`, `"private"`, `"loopback"`, `"linkLocal"`, `"multicast"`, `"unspecified"`, `"broadcast"`, `"documentation"`, `"reserved"`, ... |
| `net.ip.isPublic(text)` | `boolean` |
| `net.ip.inRange(address, ranges)` | Whether the address is in a CIDR range; `ranges` is one CIDR string or a list of them. |
| `net.ip.parseCidr("10.0.0.0/8")` | `{ version, prefix, network, first, last, size, mask? }` |

### net.interfaces

```luau
net.interfaces(): { { name: string, address: string, family: string, netmask: string, prefix: number, internal: boolean, mac: string? } }
```

The machine's network interfaces and their addresses.

## URLs

### net.url.parse

```luau
net.url.parse(url: string): (Url?, string?)
```

```luau
net.url.parse("https://u:p@Host:8443/a/b?x=1#top")
--> { scheme = "https", username = "u", password = "p", host = "host", port = 8443,
--    path = "/a/b", query = "x=1", fragment = "top" }
```

Absent parts are `nil`. Parts are not percent-decoded.

### net.url.build

```luau
net.url.build(parts: Url): string
```

```luau
net.url.build({ scheme = "https", host = "a.com", path = "/s", query = { q = "a b" } })
--> "https://a.com/s?q=a%20b"
```

`query` may be a string or a table (as for `buildQuery`).

### Other URL functions

| Function | Description |
|---|---|
| `net.url.resolve(base, reference)` | The absolute URL of a reference relative to `base` (RFC 3986: `"../x"`, `"//host/y"`, `"?q"`, ...). |
| `net.url.normalize(url)` | Lower-case scheme and host, no default port, no `.`/`..` segments. |
| `net.url.origin(url)` | `"https://example.com:8443"` |
| `net.url.defaultPort(scheme)` | `443` for `"https"`, ... |
| `net.url.encode(text, keep?)` | Percent-encodes `text`; `keep` lists extra characters to leave alone: `encode("a b/c", "/")` gives `"a%20b/c"`. |
| `net.url.decode(text, plusIsSpace?)` | Percent-decodes; with `true`, `+` means space. |
| `net.url.parseQuery(query)` | `map, pairs`: `{ a = "1", b = "2" }` and the ordered list `{ { "a", "1" }, { "b", "2" }, { "a", "3" } }`. |
| `net.url.buildQuery(params)` | From a list of pairs `{ { "a", "1" }, { "a", "2" } }`, or a map whose values are strings or lists of strings (sorted). |
| `net.idna.toAscii(domain)` | `"bücher.de"` to `"xn--bcher-kva.de"` (punycode; no Unicode normalization). |
| `net.idna.toUnicode(domain)` | The reverse. |

## HTTP/1.1

No I/O happens here: these functions turn bytes into tables and tables into bytes, so an HTTP
server, or a client that [`net.request`](#netrequest) doesn't cover, can be written on top of the
sockets in plain Luau.

### Messages

```luau
net.http.parseRequest(data: string, limits: Limits?): (Head?, number | string)
net.http.parseResponse(data: string, limits: Limits?): (Head?, number | string)
```

Parse the head (start line and headers) at the beginning of `data`. They return
`head, bytesUsed`; `nil` if the head isn't complete yet (read more and try again); or
`nil, err` if it is invalid. `limits` is `{ maxHeadSize = 64 KiB, maxHeaders = 100 }`.

A request head is `{ method, target, path, query?, version = "1.1", headers, headerList }`; a
response head is `{ version, status, reason, headers, headerList }`. `headers` has lower-case
names, with repeated headers joined by `", "` (`set-cookie` by `"\n"`). `headerList` is
`{ { name, value } }` exactly as received.

```luau
net.http.formatRequest(head: { method: string, target: string, version: string?, headers: Headers? }): string
net.http.formatResponse(head: { status: number, reason: string?, version: string?, headers: Headers? }): string
```

Produce a head, ending in the blank line. `Headers` is `{ name = value | { value } }` or
`{ { name, value } }`. Line breaks in values are refused.

| Function | Description |
|---|---|
| `net.http.bodyLength(head, { requestMethod? }?)` | How the body is delimited (RFC 9112 §6.3): `"none"`, `"length", n`, `"chunked"`, `"close"` (read until EOF), `"tunnel"`, or `nil, err`. Give `requestMethod` for responses. |
| `net.http.keepAlive(head)` | Whether the connection stays open afterwards. |
| `net.http.statusText(code)` | `statusText(404)` gives `"Not Found"`. |

### Chunked transfer coding

| Function | Description |
|---|---|
| `net.http.encodeChunk(data)` | One chunk. |
| `net.http.lastChunk(trailers?)` | The final chunk, with optional trailers. |
| `net.http.chunkedDecoder(options?)` | A decoder for a chunked body. |

A decoder has `decoder:push(bytes)` returning `bodyBytes, done` (or `nil, err`),
`decoder:rest()` for the bytes after the body, `decoder:trailers()` and `decoder:done()`.

### Headers, dates and cookies

| Function | Description |
|---|---|
| `net.http.formatDate(time?)`, `net.http.parseDate(text)` | `"Sun, 06 Nov 1994 08:49:37 GMT"` to and from Unix time. |
| `net.http.parseHeaderValue(value)` | `"text/html; charset=utf-8"` gives `"text/html", { charset = "utf-8" }`. |
| `net.http.parseList(value)` | A comma-separated list, respecting quotes. |
| `net.http.parseQuality(value)` | `"br;q=1, gzip;q=0.8"` gives `{ { value = "br", q = 1, params = {} }, ... }`. |
| `net.http.basicAuth(user, password)` | `"Basic ..."` |
| `net.http.parseBasicAuth(header)` | `user, password` |
| `net.http.parseCookies(header)` | `"a=1; b=2"` gives `{ a = "1", b = "2" }`. |
| `net.http.formatCookies(cookies)` | The reverse. |
| `net.http.parseSetCookie(header)` | `{ name, value, expires?, maxAge?, domain?, path?, secure, httpOnly, sameSite?, partitioned? }` |
| `net.http.formatSetCookie(cookie)` | The reverse. |

### Multipart

```luau
net.http.encodeMultipart(parts: { Part }, boundary: string?): (string, string)
net.http.decodeMultipart(body: string, boundaryOrContentType: string): ({ Part }?, string?)

type Part = { name: string?, value: string, filename: string?, contentType: string?, headers: { [string]: string }? }
```

`encodeMultipart` returns the body and the matching `Content-Type` header value.

### Media types

| Function | Description |
|---|---|
| `net.mime.lookup(nameOrExt)` | `lookup("photo.png")` or `lookup("png")` gives `"image/png"`. |
| `net.mime.extension(type)` | `extension("image/png")` gives `"png"`. |
| `net.mime.parse(type)` | `{ type, subtype, essence, params }` |
| `net.mime.isText(type)` | Whether the type is textual. |

## WebSocket

RFC 6455 framing, without I/O: frames go over any socket, plain or TLS. Payloads and frames
can be strings or buffers; `mask` gives back the kind it was given.

| Function | Description |
|---|---|
| `net.ws.generateKey()` | A `Sec-WebSocket-Key` for a client handshake. |
| `net.ws.acceptKey(key)` | The matching `Sec-WebSocket-Accept`. |
| `net.ws.encode(opcode, payload?, options?)` | Frame bytes. `opcode` is `"text"`, `"binary"`, `"close"`, `"ping"`, `"pong"`, `"continuation"` or 0–15. `options = { mask, fin, rsv1 }`; `mask` is `true` (clients must mask) or a 4-byte key. |
| `net.ws.decode(data, { maxPayload }?)` | `frame, bytesUsed`; `nil` if incomplete; or `nil, err`. `frame = { opcode, fin, rsv1, rsv2, rsv3, masked, payload }`, with the payload unmasked. |
| `net.ws.closePayload(code?, reason?)` | The payload of a close frame. |
| `net.ws.parseClose(payload)` | `code?, reason` |
| `net.ws.mask(data, key)` | `data` XOR the 4-byte `key`. |
