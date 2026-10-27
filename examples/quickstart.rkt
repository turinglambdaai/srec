#lang racket/base
;; Synthetic Motorola S-record example. No hardware or vendor files required.
(require srec)

(define image (bytes #xDE #xAD #xBE #xEF))
(define text
  (bytes->srec image
               #:base-address #x1000
               #:address-length-bits 16
               #:start-address #x2000))

(unless (equal? (srec->bytes text) image)
  (error 'srec-quickstart "S-record round-trip failed"))
(unless (= (srec-start-address text) #x2000)
  (error 'srec-quickstart "entry-point address was not preserved"))
(unless (pair? (parse-srec text))
  (error 'srec-quickstart "output contains no records"))

(displayln "S-record quickstart OK")
