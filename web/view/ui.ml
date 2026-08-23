(** The handful of shapes every card and panel is built from.

    Two rules hold everywhere under [view/].

    {b The class names are the React app's, verbatim.} [src/App.css] is reused
    unchanged, so the port is a pure logic port with an identical-looking result
    -- which is what makes a side-by-side screenshot worth putting in the README.
    [ppx_css] would be nicer OCaml and is not worth the parity.

    {b A field that will not parse changes nothing.} Every numeric input here
    routes through a smart constructor, and a value the constructor refuses
    raises no action at all: the input keeps showing what was typed and the world
    keeps its last legal value. That is the opposite of [Number(x) || 0], which
    turns a typo into a zero and stores it. *)

open! Core
open Bonsai_web

let text = Vdom.Node.text

let button ?(classes = []) ?(disabled = false) ?title ~on_click label =
  Vdom.Node.button
    ~attrs:
      (List.filter_opt
         [ (if List.is_empty classes then None else Some (Vdom.Attr.classes classes))
         ; (if disabled then Some Vdom.Attr.disabled else None)
         ; Option.map title ~f:Vdom.Attr.title
         ; Some (Vdom.Attr.on_click (fun _ -> on_click))
         ])
    [ text label ]
;;

let text_input ?(classes = []) ?placeholder ?(readonly = false) ~value ~on_change () =
  Vdom.Node.input
    ~attrs:
      (List.filter_opt
         [ (if List.is_empty classes then None else Some (Vdom.Attr.classes classes))
         ; Some (Vdom.Attr.value_prop value)
         ; Option.map placeholder ~f:Vdom.Attr.placeholder
         ; (if readonly then Some (Vdom.Attr.bool_property "readOnly" true) else None)
         ; Some (Vdom.Attr.on_input (fun _ text -> on_change text))
         ])
    ()
;;

(** [on_change] is handed the parsed number, and is not called at all for text
    that is not one. See the note at the top of this file. *)
let number_input ?(classes = []) ?(readonly = false) ~value ~on_change () =
  Vdom.Node.input
    ~attrs:
      (List.filter_opt
         [ (if List.is_empty classes then None else Some (Vdom.Attr.classes classes))
         ; Some (Vdom.Attr.type_ "number")
         ; Some (Vdom.Attr.value_prop value)
         ; (if readonly then Some (Vdom.Attr.bool_property "readOnly" true) else None)
         ; Some
             (Vdom.Attr.on_input (fun _ typed ->
                match Int.of_string_opt (String.strip typed) with
                | Some n -> on_change (Some n)
                | None when String.is_empty (String.strip typed) -> on_change None
                | None -> Effect.Ignore))
         ])
    ()
;;

let labelled ?(classes = []) ~label child =
  Vdom.Node.label
    ~attrs:(if List.is_empty classes then [] else [ Vdom.Attr.classes classes ])
    [ Vdom.Node.span [ text label ]; child ]
;;

let checkbox ~label ~checked ~on_change =
  Vdom.Node.label
    ~attrs:[ Vdom.Attr.class_ "toggle" ]
    [ Vdom.Node.input
        ~attrs:
          (List.filter_opt
             [ Some (Vdom.Attr.type_ "checkbox")
             ; Some (Vdom.Attr.bool_property "checked" checked)
             ; Some (Vdom.Attr.on_click (fun _ -> on_change (not checked)))
             ])
        ()
    ; text label
    ]
;;

let textarea ?placeholder ~value ~on_change () =
  Vdom.Node.textarea
    ~attrs:
      (List.filter_opt
         [ Some (Vdom.Attr.string_property "value" value)
         ; Option.map placeholder ~f:Vdom.Attr.placeholder
         ; Some (Vdom.Attr.on_input (fun _ text -> on_change text))
         ])
    []
;;

let muted ?(small = false) children =
  Vdom.Node.p
    ~attrs:[ Vdom.Attr.classes (if small then [ "muted"; "small" ] else [ "muted" ]) ]
    children
;;

(** A number the domain may refuse. [of_int] is the smart constructor; a value it
    rejects produces no action. *)
let guarded ~of_int ~f n =
  match (of_int n : _ Or_error.t) with
  | Ok value -> Some (f value)
  | Error _ -> None
;;
