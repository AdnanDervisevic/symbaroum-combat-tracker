(** About sixty lines instead of [react-toastify]. *)

open! Core
open Bonsai_web
open Symbaroum

let severity_class event =
  match Event.severity event with
  | `Info -> "toast-info"
  | `Success -> "toast-success"
  | `Warning -> "toast-warning"
  | `Error -> "toast-error"
;;

let render (toasts : App_state.Toast.t list) =
  match toasts with
  | [] -> Vdom.Node.none
  | toasts ->
    Vdom.Node.div
      ~attrs:[ Vdom.Attr.class_ "toast-stack" ]
      (List.map toasts ~f:(fun { App_state.Toast.serial; event; raised_at = _ } ->
         Vdom.Node.div
           ~key:(Int.to_string serial)
           ~attrs:[ Vdom.Attr.classes [ "toast"; severity_class event ] ]
           [ Ui.text (Event.to_string_hum event) ]))
;;
