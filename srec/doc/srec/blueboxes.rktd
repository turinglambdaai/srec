699
((3) 0 () 2 ((q lib "srec/main.rkt") (q 0 . 5)) () (h ! (equal) ((c def c (c (? . 0) q srec->bytes)) q (1329 . 4)) ((c def c (c (? . 0) q srec-start-address)) q (1450 . 4)) ((c def c (c (? . 0) q srec-record?)) c (? . 1)) ((c def c (c (? . 0) q srec-record-data)) c (? . 1)) ((c def c (c (? . 0) q struct:srec-record)) c (? . 1)) ((c def c (c (? . 0) q parse-srec)) q (163 . 3)) ((c def c (c (? . 0) q bytes->srec)) q (564 . 15)) ((c def c (c (? . 0) q srec-record-kind)) c (? . 1)) ((c def c (c (? . 0) q parse-srec-line)) q (241 . 4)) ((c def c (c (? . 0) q srec-record)) c (? . 1)) ((c def c (c (? . 0) q srec-record-address)) c (? . 1)) ((c def c (c (? . 0) q write-srec-record)) q (366 . 5))))
struct
(struct srec-record (kind address data))
  kind : (or/c 'header 'data 'count 'start)
  address : exact-nonnegative-integer?
  data : bytes?
procedure
(parse-srec text) -> (listof srec-record?)
  text : string?
procedure
(parse-srec-line line line-no) -> srec-record?
  line : string?
  line-no : exact-nonnegative-integer?
procedure
(write-srec-record  rec                              
                   [#:address-length-bits bits]) -> string?
  rec : srec-record?
  bits : (or/c 16 24 32) = 32
procedure
(bytes->srec  bs                                          
             [#:base-address base                         
              #:address-length-bits bits                  
              #:data-bytes-per-line per-line              
              #:header header                             
              #:start-address start                       
              #:trailing-newline? trailing-newline?]) -> string?
  bs : bytes?
  base : exact-nonnegative-integer? = 0
  bits : (or/c 16 24 32) = 32
  per-line : (integer-in 1 253) = 32
  header : (or/c bytes? #f) = #f
  start : (or/c exact-nonnegative-integer? #f) = #f
  trailing-newline? : boolean? = #t
procedure
(srec->bytes text [#:fill fill]) -> bytes?
  text : string?
  fill : (integer-in 0 255) = 255
procedure
(srec-start-address text)
 -> (or/c exact-nonnegative-integer? #f)
  text : string?
