#lang racket/base

;; S-record writer: record-level rendering plus image-level helpers
;; (bytes -> a full S-record text, text -> merged image bytes).

(require racket/contract
         racket/string
         "record.rkt"
         "parse.rkt")

(provide (contract-out
          [write-srec-record
           (->* (srec-record?)
                (#:address-length-bits (or/c 16 24 32))
                string?)]
          [bytes->srec
           (->* (bytes?)
                (#:base-address exact-nonnegative-integer?
                 #:address-length-bits (or/c 16 24 32)
                 #:data-bytes-per-line (integer-in 1 253)
                 #:header (or/c bytes? #f)
                 #:start-address (or/c exact-nonnegative-integer? #f)
                 #:trailing-newline? boolean?)
                string?)]
          [srec->bytes
           (->* (string?)
                (#:fill (integer-in 0 255))
                bytes?)]
          [srec-start-address (-> string? (or/c exact-nonnegative-integer? #f))]))

(define (byte->hex2 b)
  (define s (string-upcase (number->string b 16)))
  (if (< b 16) (string-append "0" s) s))

(define (bytes->hex-up bs)
  (string-append* (for/list ([b (in-bytes bs)]) (byte->hex2 b))))

(define (be-bytes v n)
  (list->bytes
   (for/list ([i (in-range (sub1 n) -1 -1)])
     (bitwise-and (arithmetic-shift v (* -8 i)) #xFF))))

(define (checksum-bytes count addr-bytes data)
  ;; everything except the checksum itself, in wire order
  (bytes-append (bytes count) addr-bytes data))

(define (render type addr-bytes data)
  (define count (+ (bytes-length addr-bytes) (bytes-length data) 1))
  (string-append "S" type
                 (byte->hex2 count)
                 (bytes->hex-up addr-bytes)
                 (bytes->hex-up data)
                 (byte->hex2 (srec-checksum (checksum-bytes count addr-bytes data)))))

;; Render one record.  Data records pick S1/S2/S3 from the width parameter;
;; count records pick S5/S6 from the count magnitude; start records pick
;; S9/S8/S7 from the width parameter.
(define (write-srec-record rec #:address-length-bits [bits 32])
  (define width (quotient bits 8))
  (case (srec-record-kind rec)
    [(header)
     (unless (<= (bytes-length (srec-record-data rec)) 253)
       (error 'write-srec-record "header longer than 253 byte(s)"))
     (render "0" (be-bytes 0 2) (srec-record-data rec))]
    [(data)
     (define data (srec-record-data rec))
     (unless (<= (bytes-length data) (- 255 width 1))
       (error 'write-srec-record "data record longer than ~a byte(s)" (- 255 width 1)))
     (define addr (srec-record-address rec))
     (unless (< addr (arithmetic-shift 1 bits))
       (error 'write-srec-record
              "address ~a does not fit in a ~a-bit record" addr bits))
     (render (case bits [(16) "1"] [(24) "2"] [else "3"])
             (be-bytes addr width) data)]
    [(count)
     (define n (srec-record-address rec))
     (cond [(<= n #xFFFF) (render "5" (be-bytes n 2) #"")]
           [(<= n #xFFFFFF) (render "6" (be-bytes n 3) #"")]
           [else (error 'write-srec-record "too many records for S6: ~a" n)])]
    [(start)
     (define addr (srec-record-address rec))
     (unless (< addr (arithmetic-shift 1 bits))
       (error 'write-srec-record
              "start address ~a does not fit in a ~a-bit record" addr bits))
     (render (case bits [(16) "9"] [(24) "8"] [else "7"])
             (be-bytes addr width) #"")]))

;; Render a whole memory image.  Emits the optional S0 header, S1/S2/S3
;; data records, the S5/S6 record-count record and the optional
;; S7/S8/S9 start record.
(define (bytes->srec bs
                     #:base-address [base 0]
                     #:address-length-bits [bits 32]
                     #:data-bytes-per-line [per-line 32]
                     #:header [header #f]
                     #:start-address [start #f]
                     #:trailing-newline? [trailing-newline? #t])
  (define width (quotient bits 8))
  (define lines '())
  (when header
    (unless (<= (bytes-length header) 253)
      (error 'bytes->srec "header longer than 253 byte(s)"))
    (set! lines (cons (render "0" (be-bytes 0 2) header) lines)))
  (unless (zero? (bytes-length bs))
    (unless (< (+ base (bytes-length bs)) (arithmetic-shift 1 bits))
      (error 'bytes->srec
             "image end address ~a exceeds the ~a-bit address range"
             (+ base (bytes-length bs) -1) bits)))
  (define data-lines
    (for/list ([offset (in-range 0 (bytes-length bs) per-line)])
      (render (case bits [(16) "1"] [(24) "2"] [else "3"])
              (be-bytes (+ base offset) width)
              (subbytes bs offset (min (bytes-length bs) (+ offset per-line))))))
  (set! lines (append (reverse data-lines) lines))
  (unless (null? data-lines)
    (set! lines (cons (write-srec-record (srec-record 'count (length data-lines) #""))
                      lines)))
  (when start
    (unless (< start (arithmetic-shift 1 bits))
      (error 'bytes->srec
             "start address ~a exceeds the ~a-bit address range" start bits))
    (set! lines (cons (render (case bits [(16) "9"] [(24) "8"] [else "7"])
                              (be-bytes start width) #"")
                      lines)))
  (string-append (string-join (reverse lines) "\n")
                 (if trailing-newline? "\n" "")))

;; Assemble the data records of an S-record image into one byte string,
;; filling gaps with `fill`.  Overlapping records are an error; count,
;; header and start records are ignored.
(define (srec->bytes text #:fill [fill #xFF])
  (define data-records
    (for/list ([r (in-list (parse-srec text))]
               #:when (eq? (srec-record-kind r) 'data))
      r))
  (when (null? data-records)
    (error 'srec->bytes "no data records in input"))
  (define sorted
    (sort data-records < #:key srec-record-address))
  (define image-start (srec-record-address (car sorted)))
  (define image-end
    (for/fold ([end 0])
              ([r (in-list sorted)])
      (max end (+ (srec-record-address r) (bytes-length (srec-record-data r))))))
  (define out (make-bytes (- image-end image-start) fill))
  ;; structural overlap check on the sorted list
  (for ([a (in-list sorted)]
        [b (in-list (cdr sorted))])
    (when (> (+ (srec-record-address a) (bytes-length (srec-record-data a)))
             (srec-record-address b))
      (error 'srec->bytes
             "records overlap at address ~a"
             (srec-record-address b))))
  (for ([r (in-list sorted)])
    (define at (- (srec-record-address r) image-start))
    (bytes-copy! out at (srec-record-data r)))
  out)

;; The start (entry) address declared by an S7/S8/S9 record, if any.
(define (srec-start-address text)
  (for/first ([r (in-list (reverse (parse-srec text)))]
              #:when (eq? (srec-record-kind r) 'start))
    (srec-record-address r)))
