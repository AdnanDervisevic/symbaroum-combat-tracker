(** About sixty lines instead of [react-toastify].

    Worth the replacement not because sixty lines is cheap but because the
    architecture underneath it changed. In the React app a toast is fired from
    inside a [setState] updater -- which must be pure, and which React may call
    twice -- so [applyAdjustment] declares a mutable ref outside, writes to it
    from inside the mapper, reads it after [setEncounter] returns, and schedules
    the flash through [setTimeout (..., 0)] to dodge a batching problem
    ({{:src/App.tsx} [App.tsx:398-435]}).

    Here {!Symbaroum.World.apply} {i returns} its events. The reducer stays pure,
    the toast text is a value a test can assert, and there is no timer: expiry is
    a tick on the same clock everything else uses. *)

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
