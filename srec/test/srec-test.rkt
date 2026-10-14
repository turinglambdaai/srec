#lang racket/base

;; Tests for the srec package.  The golden fixtures under data/ were
;; generated with the Python `bincopy` library (20.1.1) and freeze its
;; output byte-for-byte; my writer must reproduce them exactly and my
;; parser must accept them (double-implementation cross-check).

(require rackunit
         racket/file
         racket/list
         racket/runtime-path
         racket/string
         srec/record
         srec/parse
         srec/write)

(define-runtime-path data-dir "data")

(define (golden name)
  (file->string (build-path data-dir name)))

;; 53 sample bytes used across the bincopy-generated fixtures
(define sample-53 (list->bytes (for/list ([i (in-range #x35)]) i)))

;; ---------------------------------------------------------------------------
;; checksum

(test-case "srec checksum anchors"
  ;; S1071000DEADBEEFB0 -> body checksum byte B0
  (check-equal? (srec-checksum (bytes #x07 #x10 #x00 #xDE #xAD #xBE #xEF)) #xB0)
  ;; S5030001FB
  (check-equal? (srec-checksum (bytes #x03 #x00 #x01)) #xFB)
  ;; S9032000DC
  (check-equal? (srec-checksum (bytes #x03 #x20 #x00)) #xDC)
  ;; S0040000484452001D
  (check-equal? (srec-checksum (bytes #x04 #x00 #x00 #x48 #x44 #x52 #x00)) #x1D))

;; ---------------------------------------------------------------------------
;; golden fixtures from bincopy

(test-case "bincopy golden: S19 (16-bit addresses, 32 data/line)"
  (check-equal? (bytes->srec sample-53
                             #:base-address #x1000
                             #:address-length-bits 16
                             #:data-bytes-per-line 32)
                (golden "s19-53b-at-1000.srec")))

(test-case "bincopy golden: S28 (24-bit addresses, 16 data/line)"
  (check-equal? (bytes->srec sample-53
                             #:base-address #x1000
                             #:address-length-bits 24
                             #:data-bytes-per-line 16)
                (golden "s28-53b-at-1000.srec")))

(test-case "bincopy golden: S37 (32-bit addresses, 4 data/line)"
  (check-equal? (bytes->srec sample-53
                             #:base-address #x1000
                             #:address-length-bits 32
                             #:data-bytes-per-line 4)
                (golden "s37-53b-at-1000.srec")))

(test-case "bincopy golden: S19 with start address"
  (check-equal? (bytes->srec (bytes #xDE #xAD #xBE #xEF)
                             #:base-address #x1000
                             #:address-length-bits 16
                             #:data-bytes-per-line 8
                             #:start-address #x2000)
                (golden "s19-start.srec")))

(test-case "bincopy golden: S37 with start address"
  (check-equal? (bytes->srec (bytes #xDE #xAD #xBE #xEF)
                             #:base-address #x1000
                             #:address-length-bits 32
                             #:data-bytes-per-line 8
                             #:start-address #x1F0000)
                (golden "s37-start.srec")))

;; ---------------------------------------------------------------------------
;; parsing

(test-case "parse bincopy golden back to the original image"
  (check-equal? (srec->bytes (golden "s19-53b-at-1000.srec")) sample-53)
  (check-equal? (srec->bytes (golden "s28-53b-at-1000.srec")) sample-53)
  (check-equal? (srec->bytes (golden "s37-53b-at-1000.srec")) sample-53))

(test-case "parse the Wikipedia example: records, image and start address"
  (define recs (parse-srec (golden "wikipedia.srec")))
  (check-equal? (length recs) 5)
  (check-equal? (srec-record-kind (first recs)) 'header)
  (check-equal? (bytes->hex-up (srec-record-data (first recs))) "68656C6C6F20202020202000")
  (check-equal? (srec->bytes (golden "wikipedia.srec"))
                (bytes-append (bytes #x7C #x08 #x02 #xA6 #x90 #x01 #x00 #x04
                                     #x94 #x21 #xFF #xF0 #x7C #x6C #x1B #x78
                                     #x7C #x8C #x23 #x78 #x3C #x60 #x00 #x00
                                     #x38 #x63 #x00 #x00)
                              (bytes #x4B #xFF #xFF #xE5 #x39 #x80 #x00 #x00
                                     #x7D #x83 #x63 #x78 #x80 #x01 #x00 #x14
                                     #x38 #x21 #x00 #x10 #x7C #x08 #x03 #xA6
                                     #x4E #x80 #x00 #x20)))
  (check-equal? (srec-start-address (golden "wikipedia.srec")) 0))

(test-case "record kinds across all record types"
  (define recs (parse-srec (golden "s37-start.srec")))
  (check-equal? (map srec-record-kind recs) '(data count start))
  (check-equal? (srec-record-address (third recs)) #x1F0000)
  (check-equal? (srec-start-address (golden "s19-start.srec")) #x2000))

(test-case "header record round trip"
  (define header (bytes #x48 #x44 #x52 #x00))
  (define line (write-srec-record (srec-record 'header 0 header)))
  (check-equal? line "S0070000484452001A")
  (define recs (parse-srec (string-append line "\n")))
  (check-equal? (srec-record-kind (car recs)) 'header)
  (check-equal? (srec-record-data (car recs)) header))

(test-case "count record switches to S6 above 16 bits"
  (check-equal? (write-srec-record (srec-record 'count 70000 #""))
                "S60401117079")
  (check-equal? (srec-record-kind (car (parse-srec "S60401117079\n"))) 'count)
  (check-equal? (srec-record-address (car (parse-srec "S60401117079\n"))) 70000))

(test-case "lowercase hex input is accepted"
  (define recs (parse-srec "S1071000deadbeefb0\n"))
  (check-equal? (srec-record-address (car recs)) #x1000)
  (check-equal? (srec-record-data (car recs)) (bytes #xDE #xAD #xBE #xEF)))

(test-case "gap fill and image bounds"
  (define text (string-append "S1071000AABBCCDDDA\n"
                              "S1071010112233442E\n"))
  (define img (srec->bytes text))
  (check-equal? (bytes-length img) 20) ; #x1000..#x1013: 4 + 12 gap + 4
  (check-equal? (subbytes img 0 4) (bytes #xAA #xBB #xCC #xDD))
  (check-equal? (subbytes img 4 16) (make-bytes 12 #xFF))
  (check-equal? (subbytes img 16) (bytes #x11 #x22 #x33 #x44))
  ;; custom fill
  (check-equal? (subbytes (srec->bytes text #:fill 0) 4 16) (make-bytes 12 0)))

;; ---------------------------------------------------------------------------
;; rejection cases

(define (fails? thunk)
  (with-handlers ([exn:fail? (lambda (_) #t)]) (thunk) #f))

(test-case "malformed records are rejected"
  ;; bad checksum
  (check-true (fails? (lambda () (parse-srec "S1071000DEADBEEFB1\n"))))
  ;; byte count mismatch
  (check-true (fails? (lambda () (parse-srec "S1061000DEADBEEFB0\n"))))
  ;; odd number of hex digits
  (check-true (fails? (lambda () (parse-srec "S1071000DEADBEEFB\n"))))
  ;; non-hex characters
  (check-true (fails? (lambda () (parse-srec "S1071000DEADBEGG\n"))))
  ;; unknown record type
  (check-true (fails? (lambda () (parse-srec "S4030000FB\n"))))
  ;; no leading S
  (check-true (fails? (lambda () (parse-srec "X1071000DEADBEEFB0\n"))))
  ;; S5 with data
  (check-true (fails? (lambda () (parse-srec "S5040001FFFB\n"))))
  ;; S9 with data
  (check-true (fails? (lambda () (parse-srec "S904200000DB\n")))))

(test-case "address width violations are rejected on write"
  ;; #x1F000 does not fit S1 (16-bit)
  (check-true (fails? (lambda ()
                        (bytes->srec #"data"
                                     #:base-address #x1F000
                                     #:address-length-bits 16))))
  ;; a single data record too long for S1
  (check-true (fails? (lambda ()
                        (write-srec-record
                         (srec-record 'data #x1000 (make-bytes 254))
                         #:address-length-bits 16)))))

(test-case "overlapping data records are rejected"
  (check-true
   (fails? (lambda ()
             (srec->bytes "S1071000AABBCCDDDA\nS1071002112233443C\n")))))

;; ---------------------------------------------------------------------------
;; round trip via record-level API

(test-case "record-level write/parse round trip"
  (define recs (parse-srec (golden "s28-53b-at-1000.srec")))
  (define text (string-append* (for/list ([r (in-list recs)])
                                 (string-append (write-srec-record r #:address-length-bits 24)
                                                "\n"))))
  (check-equal? (parse-srec text) recs))
