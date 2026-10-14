#lang scribble/manual
@(require (for-label racket/base
                     racket/contract
                     srec)
          scribble/example)

@(define srec-eval (make-base-eval #:lang 'racket/base '(require srec)))

@title[#:tag "srec"]{srec: Motorola S-records}
@author{turinglambdaai}

@defmodule[srec]

The @filepath{srec} package reads and writes @deftech{Motorola S-record}
files — the line-oriented firmware image format (also known as SRECORD,
S19/S28/S37) burned into microcontrollers and attached to bug reports
everywhere.  Everything is implemented in pure Racket: no FFI, no system
dependency.

The writer is validated byte-for-byte against the Python
@hyperlink["https://github.com/eerimoq/bincopy"]{@tt{bincopy}} library
(its outputs ship as golden fixtures), and the parser accepts everything
@tt{bincopy} produces — plus a few things it gets wrong: record types are
strictly validated, byte counts and checksums are enforced, and addresses
are checked against the declared record width (@tt{bincopy} silently emits
malformed 16-bit records for larger addresses).

@section{Quick start}

@examples[
#:eval srec-eval
(define image (bytes #xDE #xAD #xBE #xEF))
(define text (bytes->srec image
                          #:base-address #x1000
                          #:address-length-bits 16
                          #:start-address #x2000))
(display text)
(srec->bytes text)
(srec-start-address text)
]

@section{Records}

An S-record line is @tt{S}<type>@tt{<count><address><data><checksum>}, all
hexadecimal, where @emph{count} covers the address, the data and the
checksum itself.  The checksum is the one's complement of the LSB of the
sum of count, address and data bytes — @racket[srec-checksum].

@defstruct*[srec-record ([kind (or/c 'header 'data 'count 'start)]
                         [address exact-nonnegative-integer?]
                         [data bytes?])]{
 One record line.  @racket[kind] maps the record type letters:
 @tt{S0} → @racket['header] (its @racket[data] is the header comment),
 @tt{S1}/@tt{S2}/@tt{S3} → @racket['data] (16/24/32-bit addresses),
 @tt{S5}/@tt{S6} → @racket['count] (@racket[address] carries the count
 value), and @tt{S7}/@tt{S8}/@tt{S9} → @racket['start] (the execution
 entry address).
}

@defproc[(parse-srec [text string?]) (listof srec-record?)]{
 Parses a whole file.  Blank lines are skipped and @tt{\r\n} endings are
 accepted.  Violations of the grammar — bad byte counts, checksum
 mismatches, odd hex, unknown record types, data on @tt{S5}/@tt{S7}/
 @tt{S8}/@tt{S9} records — raise @racket[exn:fail] with the line number.
}

@defproc[(parse-srec-line [line string?] [line-no exact-nonnegative-integer?]) srec-record?]{
 Parses one record line; @racket[line-no] only appears in error messages.
}

@section{Writing}

@defproc[(write-srec-record [rec srec-record?]
                            [#:address-length-bits bits (or/c 16 24 32) 32])
         string?]{
 Renders one record line (no newline).  Data records become
 @tt{S1}/@tt{S2}/@tt{S3} per @racket[bits]; count records choose
 @tt{S5} or @tt{S6} by magnitude; start records choose
 @tt{S9}/@tt{S8}/@tt{S7}.  Addresses that do not fit the declared width
 are an error.
}

@defproc[(bytes->srec [bs bytes?]
                      [#:base-address base exact-nonnegative-integer? 0]
                      [#:address-length-bits bits (or/c 16 24 32) 32]
                      [#:data-bytes-per-line per-line (integer-in 1 253) 32]
                      [#:header header (or/c bytes? #f) #f]
                      [#:start-address start (or/c exact-nonnegative-integer? #f) #f]
                      [#:trailing-newline? trailing-newline? boolean? #t])
         string?]{
 Renders a complete image: the optional @tt{S0} header, the data records,
 the @tt{S5}/@tt{S6} record count, and the optional start record.  An
 image whose end address does not fit @racket[bits] is an error.
}

@section{Images}

@defproc[(srec->bytes [text string?] [#:fill fill (integer-in 0 255) #xFF])
         bytes?]{
 Assembles the data records into one byte string spanning the lowest
 record address through the end of the highest.  Gaps are filled with
 @racket[fill]; overlapping records are an error; header, count and start
 records are ignored.
}

@defproc[(srec-start-address [text string?])
         (or/c exact-nonnegative-integer? #f)]{
 The entry address of the last @tt{S7}/@tt{S8}/@tt{S9} record, or
 @racket[#f] when the file declares none.
}

@section{License}

MIT.
