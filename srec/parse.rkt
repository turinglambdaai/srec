#lang racket/base

;; Motorola S-record parser: strict line grammar, byte-count and checksum
;; validation.  A record's kind is one of 'header (S0), 'data (S1/S2/S3),
;; 'count (S5/S6) or 'start (S7/S8/S9); for count records the address field
;; carries the count value, for start records the entry address.

(require racket/contract
         racket/string
         "record.rkt")

(provide (contract-out
          [parse-srec (-> string? (listof srec-record?))]
          [parse-srec-line (-> string? exact-nonnegative-integer? srec-record?)]
          [srec-checksum (-> bytes? (integer-in 0 255))]
          [hex->bytes (-> string? bytes?)]
          [bytes->hex-up (-> bytes? string?)]))

;; Number of address bytes per record type: S0/S1/S5/S9 = 2, S2/S6/S8 = 3,
;; S3/S7 = 4.
(define (address-byte-count type)
  (case type
    [(#\0 #\1 #\5 #\9) 2]
    [(#\2 #\6 #\8) 3]
    [(#\3 #\7) 4]
    [else #f]))

(define (record-kind type)
  (case type
    [(#\0) 'header]
    [(#\1 #\2 #\3) 'data]
    [(#\5 #\6) 'count]
    [else 'start]))

;; One's complement of the LSB of the sum: the checksum byte that closes
;; every S-record (byte count, address and data included in the sum).
(define (srec-checksum bs)
  (define s (for/sum ([b (in-bytes bs)]) b))
  (bitwise-and (bitwise-not s) #xFF))

(define (hex-digit? c)
  (or (char-numeric? c)
      (and (char>=? c #\a) (char<=? c #\f))
      (and (char>=? c #\A) (char<=? c #\F))))

(define (hex-value c)
  (cond [(char-numeric? c) (- (char->integer c) (char->integer #\0))]
        [(char>=? c #\a) (+ 10 (- (char->integer c) (char->integer #\a)))]
        [else (+ 10 (- (char->integer c) (char->integer #\A)))]))

(define (hex->bytes s)
  (unless (even? (string-length s))
    (error 'parse-srec "odd number of hex digits"))
  (list->bytes
   (for/list ([i (in-range 0 (string-length s) 2)])
     (+ (* 16 (hex-value (string-ref s i)))
        (hex-value (string-ref s (add1 i)))))))

(define (byte->hex2 b)
  (define s (number->string b 16))
  (if (< b 16) (string-append "0" s) s))

(define (bytes->hex-up bs)
  (define (hex2 b)
    (define s (string-upcase (number->string b 16)))
    (if (< b 16) (string-append "0" s) s))
  (string-append* (for/list ([b (in-bytes bs)]) (hex2 b))))

(define (big-endian bs)
  (for/fold ([v 0]) ([b (in-bytes bs)])
    (+ (* v 256) b)))

;; Parse one record line (no trailing newline).  `line-no` is 1-based and
;; only appears in error messages.
(define (parse-srec-line line line-no)
  (unless (>= (string-length line) 4)
    (error 'parse-srec "line ~a: record too short" line-no))
  (unless (char=? (string-ref line 0) #\S)
    (error 'parse-srec "line ~a: records start with 'S'" line-no))
  (define type (string-ref line 1))
  (define addr-bytes (address-byte-count type))
  (unless addr-bytes
    (error 'parse-srec "line ~a: unknown record type 'S~a'" line-no type))
  (define body (substring line 2))
  (unless (and (even? (string-length body))
               (andmap hex-digit? (string->list body)))
    (error 'parse-srec "line ~a: body is not an even string of hex digits" line-no))
  (define all (hex->bytes body))          ; count || address || data || checksum
  (define count (bytes-ref all 0))
  (unless (= (bytes-length all) (add1 count))
    (error 'parse-srec "line ~a: byte count ~a does not match ~a payload byte(s)"
           line-no count (sub1 (bytes-length all))))
  (unless (= (remainder (for/sum ([b (in-bytes all)]) b) 256) 255)
    (error 'parse-srec "line ~a: checksum mismatch" line-no))
  (define payload (subbytes all 1 count)) ; address || data
  (unless (>= (bytes-length payload) addr-bytes)
    (error 'parse-srec "line ~a: payload shorter than the ~a address byte(s)" line-no addr-bytes))
  (define address (big-endian (subbytes payload 0 addr-bytes)))
  (define data (subbytes payload addr-bytes))
  (when (memq (record-kind type) '(count start))
    (unless (zero? (bytes-length data))
      (error 'parse-srec "line ~a: S~a records carry no data" line-no type)))
  (srec-record (record-kind type) address data))

;; Parse a whole S-record image: blank lines and whitespace-only lines are
;; skipped; \r\n line endings are accepted.
(define (parse-srec text)
  (for/list ([line (in-list (string-split text "\n"))]
             [line-no (in-naturals 1)]
             #:unless (= 0 (string-length (string-trim line "\r" #:left? #t #:right? #t))))
    (parse-srec-line (string-trim line "\r" #:left? #t #:right? #t) line-no)))
