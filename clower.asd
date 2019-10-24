;;;; clower.asd

(asdf:defsystem #:clower
  :description "A simple AUR helper mimicking cower"
  :author "Taekyung Kim <Taekyung.Kim.Maths@gmail.com>"
  :homepage "https://github.com/teeghee/clower"
  :license  "GPL3"
  :version "0.0.1"
  :depends-on ("alexandria"
               "cffi"
               "cl-ppcre"
               "cl-json"
               "drakma"
               "uiop")
  :serial t
  :components ((:file "package")
               (:file "clower")))
