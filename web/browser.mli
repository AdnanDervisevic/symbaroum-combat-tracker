(** The two things the page has to ask the browser for that are not state.

    Both are the same shape: a bit of DOM the app creates, uses once and throws
    away. Kept here so that everything under [view/] can stay a pure function
    from a value to a {!Vdom.Node.t}. *)

open! Core
open Bonsai_web

(** Offers [contents] to the user as a file to save.

    Uses a [data:] URL rather than [URL.createObjectURL], which trades a size
    ceiling for having no handle to revoke and no lifetime to get wrong. A save
    file for this app is a few kilobytes, so the ceiling is not a constraint;
    if it ever becomes one, this is the one function to change. *)
val download : filename:string -> contents:string -> unit Effect.t

(** Opens a file picker and hands the text back.

    The callback is invoked from a DOM event outside Bonsai's own dispatch, which
    is what [Effect.Expert.handle_non_dom_event_exn] is for. This is the only
    place in the app that reaches for it. *)
val pick_text_file : accept:string -> on_loaded:(string -> unit Effect.t) -> unit Effect.t

(** Writes [theme] where the stylesheet looks for it. The React app does the same
    thing in an effect on [document.documentElement]. *)
val set_theme_attribute : string -> unit Effect.t
