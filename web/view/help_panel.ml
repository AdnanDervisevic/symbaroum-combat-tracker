(** Static, and a good place to say what this build is. *)

open! Core
open Bonsai_web

let render =
  Vdom.Node.section
    ~attrs:[ Vdom.Attr.class_ "panel" ]
    [ Vdom.Node.h2 [ Ui.text "Quick Help" ]
    ; Vdom.Node.ul
        (List.map
           [ "Characters tab stores your standard PCs (localStorage)."
           ; "Encounter tab pulls PCs in, builds NPCs, and tracks initiative."
           ; "Pain Threshold triggers auto-prone + warnings; amount input catches big \
              hits."
           ; "Edit per card when you need to tweak stats mid-session."
           ; "Difficulty is an absorption probability, not a heuristic. Read the \
              expected casualties before the percentage."
           ]
           ~f:(fun line -> Vdom.Node.li [ Ui.text line ]))
    ; Ui.muted
        ~small:true
        [ Ui.text
            "Rules reference: Symbaroum core book. The to-hit reconstruction and its \
             situational modifiers are documented, with what is and is not verified, in \
             doc/model.md."
        ]
    ; Ui.muted
        ~small:true
        [ Ui.text
            (let { Symbaroum.Version.branch; app } = Symbaroum.Version.upstream in
             [%string
               "OCaml port %{Symbaroum.Version.port_version}, tracking %{app} on branch \
                %{branch}."])
        ]
    ]
;;
