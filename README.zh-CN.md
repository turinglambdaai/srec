# srec — Motorola S-records in pure Racket

[English](README.md) · **中文**

[![CI](https://github.com/turinglambdaai/srec/actions/workflows/ci.yml/badge.svg)](https://github.com/turinglambdaai/srec/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`srec` 读写 **Motorola S-record** 文件——这是一种面向行的固件镜像格式（也称 SRECORD、S19/S28/S37），被烧录进各种微控制器，也常出现在各类 bug 报告的附件里。

全部功能以纯 Racket 实现：无 FFI，无系统依赖。写出器与 Python 的 [bincopy](https://github.com/eerimoq/bincopy) 做过逐字节对照验证（其输出作为 golden fixture 随包发布）；解析器则比 bincopy 更进一步：记录类型严格校验，强制检查字节数与校验和，地址会对照声明的记录宽度进行检查——而 bincopy 对较大的地址会静默生成畸形的 16 位记录。

## 安装

```
raco pkg install srec
```

## 用法

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

### 记录

`srec-record` 对一行记录建模：`kind` 为 `'header`（S0）、`'data`（S1/S2/S3）、`'count`（S5/S6，计数值位于地址字段）或 `'start`（S7/S8/S9）。`parse-srec` 强制执行完整文法——错误的字节数、校验和不匹配、奇数长度的十六进制、未知类型、在 count/start 记录上携带数据——并报告行号。

### 镜像

`srec->bytes` 将数据记录组装成一个字节串，空隙以填充字节填补（默认 `#xFF`），并拒绝地址重叠。`bytes->srec` 将一段镜像渲染为 S-record，地址宽度可配置（16/24/32 位 → S1/S2/S3）、每行数据字节数可配置、S0 头与起始记录均可选。

## 许可证

[MIT](LICENSE)。
