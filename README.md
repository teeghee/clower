# clower
### _Taekyung Kim <Taekyung.Kim.Maths@gmail.com>_

A simple [AUR](https://aur.archlinux.org/) helper.

![](./made-with-lisp-flat.svg)

(Lisp Lizard logo originally designed by Manfred Spiller, adopted into
svg file by [azzamsa](https://github.com/azzamsa/lisp-logo).)

## Installation

At the moment, the best way to use this program is with a working
common lisp implementation (e.g. [sbcl](http://www.sbcl.org/)) with
[quicklisp](https://www.quicklisp.org/beta/):
```common-lisp
(quicklisp:quickload :clower)
```

One also needs Arch Linux package manager
[pacman](https://wiki.archlinux.org/index.php/pacman), its backend
`libalpm` and git installed in your system.

## Documentation

* [Variable] **\*default-download-directory\***

Default directory where AUR packages are cloned into.  The default
value is `"~/aur/"`.

* [Function] **list-alien-packages**

Returns the list of packages, which is the output of the pacman
command `pacman -Qm`.  Elements of the list are not mere strings, but
instances of **archpackage** structure.

* [Function] **sync-packages** (*&optional listpkg*)

Given the list of archpackages, make http query to AUR server and
return unsynchronised archpackages (i.e. there are available updates
in AUR server, no corresponding package in AUR server, etc.) with
appropriate *status* field of the archpackage structure.  The optional
argument **listpkg** defaults to the return value of the function
**list-alien-packages**.

* [Function] **download-packages** (*pkglist &optional basedir*)

Cloning packages in **pkglist** into **basedir**.  **pkglist** must be
a list of **archpackage** structure, and **basedir** defaults to the
variable **\*default-download-directory\***.

* [Function] **download-updates** (*&optional basedir*)

This function calls **download-packages** with all installed alien
packages (result of **list-alien-packages**) that have available
updates in AUR (i.e. **sync-packages** return **:update-available**
status).  As the result, all updates are cloned from AUR git server to
**basedir**.  The optional argument **basedir** defaults to the
variable **\*default-download-directory\***.

## License

GPL3.  See [COPYING](./COPYING).

