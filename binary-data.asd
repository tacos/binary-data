(asdf:defsystem :binary-data
  :depends-on (:closer-mop :nutils :eos :flexi-streams)
  :serial t
  :components
  ((:file "package")
   (:file "metaclasses")
   (:file "binary-data")
   (:file "tests")
 #+ ()  (:module :src
            :components
            ((:file "user-macros")))
#+ ()   (:module :tests
            :serial t
            :components
            ((:file "little-endian")))))
