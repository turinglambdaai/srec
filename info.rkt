#lang info

(define version "0.1")
;; Multi-collection package shape: the collection is the `srec/` subdirectory.
(define collection 'multi)
;; rackunit-lib is a run-time dependency because the package ships its test
;; suite and the catalog's dependency check scans shipped modules in run mode.
(define deps '("base" "rackunit-lib"))
(define build-deps '("base" "scribble-lib" "racket-doc" "rackunit-lib"))
(define pkg-desc "Pure-Racket Motorola S-record (SRECORD/S19/S28/S37) reader/writer: strict parser, checksum validation, image assembly and golden-anchor round trips")
(define pkg-authors '("turlamai"))
(define license 'MIT)
;; Documentation is declared in srec/info.rkt (collection level) — `raco
;; setup` only discovers scribblings from a collection's own info.rkt for
;; `collection 'multi` packages.
(define test-omit-paths '("srec/scribblings"))
