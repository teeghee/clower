;;;; clower.lisp

(in-package #:clower)

;;; Structure ARCHPACKAGE

(defstruct archpackage
  "Arch linux package."
  (name "" :type string :read-only t)
  (version "" :type string :read-only t)
  (status :not-specified :type symbol))

;;; Retrieve the list of alien packages.

(defun parse-pacman-result (strm)
  "Parse the output package list (whitespace separated string format
  consisting of package name and its version) from the stream, and
  make it into an alist."
  (labels ((make-package-from-string (s)
             (let ((split (cl-ppcre:split "\\s" s)))
               (make-archpackage :name (first split)
                                 :version (second split))))
           (recur (strm acc)
             (let ((line (read-line strm nil strm)))
               (if (streamp line)
                   (nreverse acc)
                   (recur strm (cons (make-package-from-string line)
                                     acc))))))
    (recur strm nil)))

(defun list-alien-packages ()
  "Return the output stream from the shell command `pacman -Qm'."
  (values (uiop:run-program '("pacman" "-Qm")
                            :output #'parse-pacman-result)))

(defun max-uri-length-safe-p (pkglist)
  "Is it safe to turn PKGLIST into a single request?"
  (< (+ 44 ;; "https://aur.archlinux.org/rpc/?v=5&type=info" part
        (reduce #'+ pkglist
                :key #'(lambda (pkg)
                         (+ 7 ;; "&arg[]=" part
                            (length (archpackage-name pkg))))))
     4443))

(defun split-uri-length-safe-lists (pkglist)
  "Split PKGLIST into uri length safe packages lists."
  (if (max-uri-length-safe-p pkglist)
      (list pkglist)
      (let ((n (floor (length pkglist) 2)))
        (append (split-uri-length-safe-lists (subseq pkglist 0 n))
                (split-uri-length-safe-lists (subseq pkglist n))))))

(defun make-single-request-parameter (pkglist)
  "Make parameters alists for `http-request'.  The size of PKGLIST is
  assumed to fit in a single request."
  (acons "v" "5"
         (acons "type" "info"
                (mapcar #'(lambda (pkg)
                            (cons "arg[]" (archpackage-name pkg)))
                        pkglist))))

(defun request-info (parameter)
  "Make info request to AUR server.  Return parsed json data."
  (with-open-stream (strm (drakma:http-request
                           "https://aur.archlinux.org/rpc/"
                           :parameters parameter
                           :want-stream t))
    (cl-json:decode-json strm)))

(defun make-aur-package-list (raw-json)
  "From parsed json datum, construct ARCHPACKAGE lists."
  (let ((results (cdr (assoc :results raw-json))))
    (mapcar #'(lambda (raw-pkg)
                (make-archpackage :name (cdr (assoc :*name raw-pkg))
                                  :version (cdr (assoc :*version
                                                       raw-pkg))
                                  :status :retrieved-from-aur))
            results)))

;;; Use libalpm function alpm_pkg_vercmp by cffi.

(cffi:define-foreign-library libalpm
  (:unix (:or "libalpm.so.12" "libalpm.so"))
  (t (:default "libalpm")))

(cffi:use-foreign-library libalpm)

(cffi:defcfun "alpm_pkg_vercmp" :int
  "Compare two versions.  Output:
   < 0 : if fullver1 < fullver2, 
     0 : if fullver1 == fullver2,
   > 0 : if fullver1 > fullver2."
  (ver1 :string)
  (ver2 :string))

(defun compare-versions-tag (localpkg aurpkg)
  "Compare packages LOCALPKG and AURPKG.  Compare their names and
  versions and return appropriate tags."
  (cond ((null aurpkg)
         :not-available-in-aur)
        ((string/= (archpackage-name localpkg)
                   (archpackage-name aurpkg))
         :not-available-in-aur)
        (t
         (let ((vercmp (alpm-pkg-vercmp
                        (archpackage-version localpkg)
                        (archpackage-version aurpkg))))
           (cond ((minusp vercmp)
                  :update-available)
                 ((plusp vercmp)
                  :local-is-newer)
                 (t nil))))))

;;; Package comparison

(defun compare-packages (localpkgs aurpkgs)
  "Compare versions of the packages in LOCALPKGS against AURPKGS.  Two
  package lists are assumed to be sorted by their names."
  (labels ((recur (locals aurs acc)
             (if (null locals)
                 (nreverse acc)
                 (let* ((localpkg (first locals))
                        (aurpkg (first aurs))
                        (tag (compare-versions-tag localpkg aurpkg)))
                   (cond ((eq tag :not-available-in-aur)
                          (setf (archpackage-status localpkg) tag)
                          (recur (rest locals)
                                 aurs
                                 (cons localpkg acc)))
                         (tag
                          (setf (archpackage-status localpkg) tag)
                          (recur (rest locals) (rest aurs)
                                 (cons localpkg acc)))
                         (t
                          (recur (rest locals) (rest aurs) acc)))))))
    (recur localpkgs aurpkgs nil)))

(defun retrieve-corresponding-aur-packages (pkglist)
  "From PKGLIST, do make http request to AUR server and reconstruct
  archpackage lists from response."
  (reduce #'nconc 
          (mapcar (alexandria:compose #'make-aur-package-list
                                      #'request-info
                                      #'make-single-request-parameter)
                  (split-uri-length-safe-lists pkglist))))

(defun sync-packages (&optional (pkglist (list-alien-packages)))
  "From PKGLIST, retrieve aur package lists and compare them."
  (let ((aurpkgs (retrieve-corresponding-aur-packages pkglist)))
    (compare-packages pkglist aurpkgs)))

(defun pickout-updated-packages (pkglist)
  "Given PKGLIST, pick out packages that have available updates in
  AUR."
  (let ((result nil))
    (dolist (pkg pkglist (nreverse result))
      (when (eq (archpackage-status pkg) :update-available)
        (push pkg result)))))

;;; Downloading packages

(defvar *default-download-directory*
  (merge-pathnames "aur/" (user-homedir-pathname))
  "Default directory where new AUR packages are cloned into.")

(defun prepare-download-repository (pkg basedir)
  "Probe if there is a directory (or file) of the name of PKG inside
  BASEDIR."
  (let ((repo (merge-pathnames (archpackage-name pkg) basedir)))
    (not (probe-file repo))))

(defun download-package
    (pkg &optional (basedir *default-download-directory*))
  "Clone PKG into DOWNLOAD-DIR."
  (when (prepare-download-repository pkg basedir)
    (let ((uri (concatenate 'string
                            "https://aur.archlinux.org/"
                            (archpackage-name pkg)
                            ".git"))
          (localpath-as-string
           (namestring (merge-pathnames (archpackage-name pkg)
                                        basedir))))
      (zerop (nth-value 2 (uiop:run-program (list "git" "clone"
                                                  uri
                                                  localpath-as-string)
                                            :output t))))))

(defun download-packages
    (pkglist &optional (basedir *default-download-directory*))
  "Download all the packages in PKGLIST into BASEDIR."
  (let ((result nil))
    (dolist (pkg pkglist (nreverse result))
      (when (download-package pkg basedir)
        (push pkg result)))))

(defun download-updates
    (&optional (basedir *default-download-directory*))
  "Download all the packages that have updates available in AUR
  server."
  (download-packages (sync-packages) basedir))

