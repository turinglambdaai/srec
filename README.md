# srec — Motorola S-records in pure Racket

**English** · [中文](README.zh-CN.md)

[![CI](https://github.com/turinglambdaai/srec/actions/workflows/ci.yml/badge.svg)](https://github.com/turinglambdaai/srec/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`srec` reads and writes **Motorola S-record** files — the line-oriented
firmware image format (also known as SRECORD, S19/S28/S37) burned into
microcontrollers and attached to bug reports everywhere.

Everything is implemented in pure Racket: no FFI, no system dependency.
The writer is validated byte-for-byte against Python's
[bincopy](https://github.com/eerimoq/bincopy) (its outputs ship as golden
fixtures), and the parser goes further than bincopy: record types are
strictly validated, byte counts and checksums are enforced, and addresses
are checked against the declared record width — bincopy silently emits
malformed 16-bit records for larger addresses.

## Installation

```
raco pkg install srec
```

## Usage

```racket
(require srec)

(define image (bytes #xDE #xAD #xBE #xEF))
(define text (bytes->srec image
                          #:base-address #x1000
                          #:address-length-bits 16
                          #:start-address #x2000))
;; S1071000DEADBEEFB0
;; S5030001FB
;; S9032000DC

(srec->bytes text)          ; => #"\336\255\276\357"
(srec-start-address text)   ; => 8192
```

### Records

`srec-record` models one line: `kind` is `'header` (S0), `'data`
(S1/S2/S3), `'count` (S5/S6, with the count in the address field) or
`'start` (S7/S8/S9).  `parse-srec` enforces the full grammar — bad byte
counts, checksum mismatches, odd hex, unknown types, data on
count/start records — and reports the line number.

### Images

`srec->bytes` assembles the data records into one byte string, filling
gaps with a fill byte (default `#xFF`) and rejecting overlaps.
`bytes->srec` renders an image with configurable address width
(16/24/32 bit → S1/S2/S3), data bytes per line, optional S0 header and
optional start record.

## License

[MIT](LICENSE).
