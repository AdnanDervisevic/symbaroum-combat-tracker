open! Core
open Js_of_ocaml

let store () = Js.Optdef.to_option Dom_html.window##.localStorage
let is_available () = Option.is_some (store ())

let find key =
  match store () with
  | None -> None
  | Some store ->
    (* [getItem] returns null for a missing key, which [Js.Opt] models. *)
    Js.Opt.to_option (store##getItem (Js.string key)) |> Option.map ~f:Js.to_string
;;

let set key ~data =
  match store () with
  | None -> Or_error.error_string "This browser is not letting the page store anything."
  | Some store ->
    (* The write that actually fails in practice is the one past the quota, and
       it fails by raising. *)
    Or_error.try_with (fun () -> store##setItem (Js.string key) (Js.string data))
    |> Or_error.tag ~tag:[%string "Could not save %{key}"]
;;

let remove key =
  match store () with
  | None -> ()
  | Some store -> store##removeItem (Js.string key)
;;
