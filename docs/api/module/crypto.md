# @sonata/crypto

Hashing, message authentication, key derivation, encryption, signatures and secure random
values. Everything is implemented inside Sonata; no external library is needed.

```luau
local crypto = require("@sonata/crypto")

print(crypto.hash("sha256", "hello", "hex"))
--> 2cf24dba5fb0a30e26e83b2a9b5b7d6c...
```

**Binary data.** Keys, digests, ciphertexts and signatures are binary strings. Functions with an
optional `enc` argument can encode their output instead: `"hex"`, `"base64"`, `"base64url"` or
`"base32"`. Use [`crypto.encode`](#cryptoencode) and [`crypto.decode`](#cryptodecode) to convert
yourself.

**Errors:** bad arguments (unknown algorithm, wrong key length, ...) raise. Failures that depend
on the data (a ciphertext that doesn't authenticate, the system's random source being
unavailable) return `nil, message`.

## Constants

| Name | Description |
|---|---|
| `crypto.hashes` | The supported hash algorithms. |
| `crypto.ciphers` | The supported cipher names. |
| `crypto.hardwareAes` | `true` if AES runs on dedicated CPU instructions (AES-NI). |

Hash algorithms: `md5`, `sha1`, `sha224`, `sha256`, `sha384`, `sha512`, `sha3-224`, `sha3-256`,
`sha3-384`, `sha3-512`, `blake2b`, `blake2s`.

!!! warning

    `md5` and `sha1` are broken for security purposes. Use them only for compatibility with
    existing formats.

## Hashing

### crypto.hash

```luau
crypto.hash(algorithm: string, data: string, enc: string?): string
```

The digest of `data`.

### crypto.hmac

```luau
crypto.hmac(algorithm: string, key: string, data: string, enc: string?): string
```

An HMAC of `data` with `key`.

```luau
local signature = crypto.hmac("sha256", secret, body, "hex")
```

### crypto.equals

```luau
crypto.equals(a: string, b: string): boolean
```

Compares two strings in constant time (for equal lengths). Use it to compare MACs and tokens,
so timing doesn't leak how many bytes matched.

## Key derivation

### crypto.pbkdf2

```luau
crypto.pbkdf2(algorithm: string, password: string, salt: string, iterations: number, length: number, enc: string?): string
```

PBKDF2 with the given hash. `length` is the number of output bytes (up to 65536).

### crypto.pbkdf2Timed

```luau
crypto.pbkdf2Timed(algorithm: string, password: string, salt: string, ms: number, length: number, enc: string?): (string, number)
```

Like `pbkdf2`, but picks the iteration count so the derivation takes about `ms` milliseconds
(1 to 60000) on this machine. Returns the key and the iteration count used; store the count to
derive the same key later.

### crypto.hkdf

```luau
crypto.hkdf(algorithm: string, ikm: string, salt: string?, info: string?, length: number, enc: string?): string
```

HKDF (RFC 5869): derives `length` bytes (up to 255 × the digest size) from input key material.

### crypto.scrypt

```luau
crypto.scrypt(password: string, salt: string, N: number, r: number, p: number, length: number, enc: string?): string
```

scrypt. `N` must be a power of two ≥ 2, `r` in 1..256, `p` in 1..1024, and `N × r` at most
2^20 (128 MiB of memory).

```luau
local key = crypto.scrypt(password, salt, 16384, 8, 1, 32)
```

## Passwords

### crypto.hashPassword

```luau
crypto.hashPassword(password: string, ms: number?): string
```

Hashes a password for storage with PBKDF2-SHA256 and a random 16-byte salt. The cost is tuned
so hashing takes about `ms` milliseconds (default 100). The result is a self-describing string:

```
$pbkdf2-sha256$<iterations>$<salt base64>$<hash base64>
```

### crypto.verifyPassword

```luau
crypto.verifyPassword(password: string, encoded: string): boolean
```

Checks a password against a string produced by `hashPassword`. Malformed strings give `false`.

```luau
local stored = crypto.hashPassword("hunter2")
print(crypto.verifyPassword("hunter2", stored)) --> true
```

## Encryption

### crypto.encrypt

```luau
crypto.encrypt(cipher: string, key: string, data: string, options: { aad: string?, iv: string? }?): string?
```

Encrypts `data`. Unless `options.iv` is given, a random IV/nonce is generated and **prepended
to the result**, so `decrypt` can find it. For authenticated ciphers (`*-gcm`, `*-poly1305`),
the 16-byte tag is appended, and `options.aad` is additional data that is authenticated but not
encrypted.

### crypto.decrypt

```luau
crypto.decrypt(cipher: string, key: string, data: string, options: { aad: string?, iv: string? }?): (string?, string?)
```

Decrypts what `encrypt` produced. Returns `nil, "authentication failed"` if an authenticated
ciphertext was tampered with (or the key or AAD is wrong). If you passed `iv` to `encrypt`,
pass the same one here.

```luau
local key = crypto.randomBytes(32)
local sealed = crypto.encrypt("xchacha20-poly1305", key, "secret message")
print(crypto.decrypt("xchacha20-poly1305", key, sealed)) --> secret message
```

### Ciphers

| Cipher | Key bytes | IV/nonce bytes | Authenticated |
|---|---|---|---|
| `chacha20-poly1305` | 32 | 12 | yes |
| `xchacha20-poly1305` | 32 | 24 | yes |
| `chacha20`, `xchacha20` | 32 | 12, 24 | no |
| `salsa20`, `xsalsa20` | 32 | 8, 24 | no |
| `aes-128-<mode>`, `aes-192-<mode>`, `aes-256-<mode>` | 16, 24, 32 | see modes | `gcm` only |
| `sm4-<mode>` | 16 | see modes | `gcm` only |
| `speck-128-<mode>`, `speck-192-<mode>`, `speck-256-<mode>` | 16, 24, 32 | see modes | `gcm` only |
| `xtea-<mode>` | 16 | see modes (no `gcm`) | no |

Block cipher modes: `ecb` (no IV), `cbc` (PKCS#7 padding), `ctr`, `cfb`, `ofb` (IV = one
block: 16 bytes, 8 for xtea), and `gcm` (12-byte nonce, 16-byte block ciphers only).

!!! tip

    Prefer `xchacha20-poly1305` or `aes-256-gcm`. Unauthenticated modes don't detect tampering,
    and `ecb` leaks patterns in the data.

## Public-key cryptography

Keys are raw 32-byte strings.

### crypto.keypair

```luau
crypto.keypair(kind: "ed25519" | "x25519"): (string, string)
```

Generates a key pair and returns `publicKey, privateKey`. `ed25519` keys are for signatures,
`x25519` keys for key agreement and sealing.

### crypto.sign

```luau
crypto.sign(privateKey: string, message: string, enc: string?): string
```

An Ed25519 signature (64 bytes) of `message`.

### crypto.verify

```luau
crypto.verify(publicKey: string, message: string, signature: string): boolean
```

Checks an Ed25519 signature.

```luau
local public, private = crypto.keypair("ed25519")
local sig = crypto.sign(private, "release-1.0.tar.gz contents")
print(crypto.verify(public, "release-1.0.tar.gz contents", sig)) --> true
```

### crypto.sharedSecret

```luau
crypto.sharedSecret(privateKey: string, peerPublicKey: string, enc: string?): string?
```

X25519 key agreement: both sides compute the same 32-byte secret from their own private key and
the other's public key. Returns `nil, "invalid public key"` for a degenerate key. Feed the result
through [`hkdf`](#cryptohkdf) before using it as an encryption key.

### crypto.seal

```luau
crypto.seal(recipientPublicKey: string, message: string): string?
```

Encrypts `message` for the holder of an X25519 private key, without any prior exchange. Uses an
ephemeral key pair, HKDF-SHA256 and XChaCha20-Poly1305. The output is
`ephemeralPublic (32) .. nonce (24) .. ciphertext .. tag (16)`.

### crypto.open

```luau
crypto.open(privateKey: string, sealed: string): (string?, string?)
```

Decrypts a sealed message with the recipient's X25519 private key. Returns `nil, message` if it
doesn't authenticate.

```luau
local public, private = crypto.keypair("x25519")
local box = crypto.seal(public, "for your eyes only")
print(crypto.open(private, box)) --> for your eyes only
```

## Random values and identifiers

All randomness comes from the operating system's secure random source.

### crypto.randomBytes

```luau
crypto.randomBytes(n: number, enc: string?): string
```

`n` random bytes (up to 1 MiB).

### crypto.randomInt

```luau
crypto.randomInt(min: number, max: number): number
```

A uniformly distributed integer between `min` and `max`, inclusive.

### crypto.uuid

```luau
crypto.uuid(version: number?, namespace: string?, name: string?): string
```

A UUID string such as `"3b241101-e2bb-4255-8caf-4136c566a962"`.

| Version | How it's made |
|---|---|
| `4` (default) | Random. |
| `7` | Unix milliseconds followed by random bits; sorts by creation time. |
| `1` | Time-based, with a random node ID. |
| `3`, `5` | Name-based (MD5 / SHA-1): the same `namespace` and `name` always give the same UUID. `namespace` is a UUID or one of `"dns"`, `"url"`, `"oid"`, `"x500"`. |

```luau
crypto.uuid()                           --> random
crypto.uuid(5, "dns", "example.com")    --> always the same
```

### crypto.ulid

```luau
crypto.ulid(): string
```

A [ULID](https://github.com/ulid/spec): 26 characters of Crockford base32, a millisecond
timestamp followed by 80 random bits. ULIDs sort by creation time.

### crypto.totp

```luau
crypto.totp(secret: string, options: { digits: number?, period: number?, hash: string?, time: number? }?): string
```

A time-based one-time password (RFC 6238), as used by authenticator apps. Defaults: 6 digits,
30-second period, `sha1`, the current time. `secret` is the raw key; decode it first if you have
it in base32:

```luau
local secret = crypto.decode("base32", "JBSWY3DPEHPK3PXP")
print(crypto.totp(secret)) --> "492039"
```

## Encoding

### crypto.encode

```luau
crypto.encode(format: string, data: string): string
```

Encodes binary data as `"hex"`, `"base64"`, `"base64url"` or `"base32"`.

### crypto.decode

```luau
crypto.decode(format: string, text: string): string?
```

Decodes text in one of those formats, or returns `nil` if it isn't valid.
