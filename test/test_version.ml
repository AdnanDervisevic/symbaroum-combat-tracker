open! Core
open! Expect_test_helpers_core

(* Phase 0 smoke test. Proves the whole chain works end to end: [Core] is
   linked, [ppx_jane] ran the [sexp_of] derivation, [ppx_expect] collected the
   test, and [Expect_test_helpers_core] printed it. If this passes, Phase 1 can
   start. *)
let%expect_test "upstream is the React app on master" =
  print_s [%sexp (Symbaroum.Version.upstream : Symbaroum.Version.upstream)];
  [%expect
    {|
    ((branch master)
     (app    symbaroum-combat-tracker)) |}]
;;
