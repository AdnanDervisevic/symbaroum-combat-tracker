(** The roster tab. *)

open! Core
open Bonsai_web
open Symbaroum

let render ~inject ~export ~import (roster : Roster.t) =
  Vdom.Node.section
    ~attrs:[ Vdom.Attr.class_ "panel" ]
    [ Vdom.Node.div
        ~attrs:[ Vdom.Attr.class_ "panel-header" ]
        [ Vdom.Node.h2 [ Ui.text "Player Characters" ]
        ; Vdom.Node.div
            ~attrs:[ Vdom.Attr.classes [ "panel-actions"; "wrap" ] ]
            [ Ui.button ~on_click:(inject App_state.Action.New_character) "Add Character"
            ; Ui.button ~on_click:export "Export"
            ; Ui.button ~on_click:import "Import"
            ]
        ]
    ; Vdom.Node.div
        ~attrs:[ Vdom.Attr.classes [ "cards"; "two-col" ] ]
        (List.map (Roster.to_list roster) ~f:(fun character ->
           Character_card.render ~inject character))
    ]
;;
