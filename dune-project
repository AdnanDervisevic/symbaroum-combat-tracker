(lang dune 3.16)

(name symbaroum)

(generate_opam_files true)

(source
 (github AdnanDervisevic/symbaroum-combat-tracker))

(authors "Adnan Dervisevic")
(maintainers "Adnan Dervisevic")
(license MIT)

(package
 (name symbaroum)
 (synopsis "Pure combat engine and probability model for the Symbaroum RPG")
 (description
  "The domain core: encounter state, commands, undo, import/export codec, and an\
   exact absorption-probability model for encounter difficulty. Depends on no\
   JavaScript runtime -- `dune build -p symbaroum` is the CI check that keeps it\
   that way.")
 (depends
  (ocaml
   (>= 5.2.0))
  (core
   (>= v0.16))
  ppx_jane
  base_quickcheck
  yojson
  ppx_yojson_conv
  (expect_test_helpers_core :with-test)))

(package
 (name symbaroum_web)
 (synopsis "Bonsai web UI for the Symbaroum combat tracker")
 (depends
  (ocaml
   (>= 5.2.0))
  (symbaroum
   (= :version))
  bonsai
  virtual_dom
  js_of_ocaml
  js_of_ocaml-ppx))
