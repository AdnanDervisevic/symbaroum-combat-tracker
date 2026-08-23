(** [window.localStorage], with the failures made explicit.

    Bonsai has no first-class binding for this ([Persistent_var] is a different
    thing), so it is about thirty lines over [Dom_html.window##.localStorage].
    Two of those lines are the point.

    The store may be {i absent} -- private browsing in some browsers, or a
    sandboxed frame -- which JavaScript signals by the property being undefined,
    so every function here has to cope with there being no store at all.

    And {!set} returns [Or_error.t] rather than swallowing. Writing past the
    quota raises [QuotaExceededError], which the React app catches and
    [console.warn]s
    ({{:src/hooks/usePersistentState.ts} [usePersistentState.ts:53]}) -- so the
    user's fight silently stops being saved and nothing tells them. A GM who has
    lost a session's notes deserves better than a line in a console they will
    never open. *)

open! Core

(** [None] when the key is absent {i or} when there is no store. *)
val find : string -> string option

val set : string -> data:string -> unit Or_error.t
val remove : string -> unit

(** Whether there is a store at all, for a UI that wants to say so once rather
    than failing quietly on every write. *)
val is_available : unit -> bool
