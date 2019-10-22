# clower
### _Taekyung Kim <Taekyung.Kim.Maths@gmail.com>_

A simple [AUR](https://aur.archlinux.org/) helper.

![](./made-with-lisp-flat.svg)[^logo]

[^logo]: Lisp Lizard logo originally designed by Manfred Spiller, adopted into svg file by [azzamsa](https://github.com/azzamsa/lisp-logo).

## Installation

At the moment, the best way to use this program is with a working
common lisp implementation (e.g. [sbcl](http://www.sbcl.org/)) with [quicklisp](https://www.quicklisp.org/beta/):
```common-lisp
(quicklisp:quickload :clower)
```

One also needs Arch Linux package manager [pacman](https://wiki.archlinux.org/index.php/pacman), its backend `libalpm` and git installed in your system.

## License

GPL3.  See [COPYING](./COPYING).

