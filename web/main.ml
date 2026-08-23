open! Core
open! Bonsai_web

(* Phase 0 exit gate. Deliberately the smallest thing that exercises the whole
   UI toolchain at once: Bonsai's Proc-style [Computation.t], a [Vdom] tree,
   [ppx_jane] and [js_of_ocaml-ppx] running together, and a link against the
   [symbaroum] core library -- which proves the domain code and the web code can
   coexist in one binary before any real UI exists. *)

let component : Vdom.Node.t Bonsai.Computation.t =
  let { Symbaroum.Version.branch; app } = Symbaroum.Version.upstream in
  Bonsai.const
    (Vdom.Node.div
       [ Vdom.Node.h1 [ Vdom.Node.text "Symbaroum Combat Tracker" ]
       ; Vdom.Node.p
           [ Vdom.Node.text
               [%string
                 "OCaml port %{Symbaroum.Version.port_version}, tracking %{app} on \
                  branch %{branch}."]
           ]
       ])
;;

let () = Start.start ~bind_to_element_with_id:"app" component
