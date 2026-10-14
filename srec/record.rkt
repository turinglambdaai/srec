#lang racket/base

;; The S-record data model: one struct per record line.

(require racket/contract)

(provide (contract-out
          (struct srec-record ((kind (or/c 'header 'data 'count 'start))
                               (address exact-nonnegative-integer?)
                               (data bytes?)))))

(struct srec-record (kind address data) #:transparent)
