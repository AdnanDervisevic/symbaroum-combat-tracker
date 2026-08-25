(** One state machine for the whole app. *)

open! Core
open Bonsai_web
open Symbaroum

(** [World.t] as a Bonsai model.

    Bonsai wants a sexp round trip; the domain types deliberately have none,
    because deriving [t_of_sexp] on them would construct records directly and
    reintroduce every illegal state (see {!Symbaroum.Json_decoder}). So it goes
    out through the wire types and back in through the smart constructors -- the
    same path a save file takes. *)
module World_model : Bonsai.Model with type t = World.t

module Toast : sig
  (** An {!Symbaroum.Event.t} on its way to the screen, with enough to expire it.

      Events are {i returned} by [World.apply] rather than fired from inside it,
      which is what makes this a queue rather than the React app's arrangement:
      a mutable ref written from inside a [setState] updater, read after it
      returns, and flushed through [setTimeout (..., 0)] to dodge a batching
      problem ({{:src/App.tsx} [App.tsx:398-435]}). *)
  type t =
    { serial : int
    ; event : Event.t
    ; raised_at : Time_ns.Alternate_sexp.t
    }
  [@@deriving sexp, equal]

  val lifetime : Time_ns.Span.t
end

module Model : sig
  type t =
    { history : World.t Undo_history.t
    ; next_id : int (** the id supply; see the note above *)
    ; toasts : Toast.t list
    ; storage_error : string option
      (** Set when a save failed, so the UI can say so once rather than
            failing quietly forever. *)
    }
  [@@deriving sexp, equal]

  val initial : t
end

module Action : sig
  type t =
    | Apply of Symbaroum.Action.t
    (** Everything that needs nothing minted. The domain action is passed
            straight through. *)
    | New_character
    | Send_to_fight of Ids.Character_id.t list
    | Add_npcs of Npc_draft.t
    | Clear_encounter
    | Undo
    | Redo
    | Replace_world of World.t (** an import, or the load at startup *)
    | Expire_toasts
    | Note_storage_error of string option
  [@@deriving sexp_of]
end

type t =
  { world : World.t
  ; can_undo : bool
  ; can_redo : bool
  ; toasts : Toast.t list
  ; storage_error : string option
  ; inject : Action.t -> unit Effect.t
  }

val component : t Computation.t

(** {1 Persistence}

    The key this port writes. The five [sct.v1.*] keys are still {i read}, by
    {!Symbaroum.Codec.of_local_storage_v1}, and are never written again. *)

val storage_key : string

(** Present, plus this much past. The React app persists {b no} past at all --
    [usePersistentHistory] writes only [history.present] -- so keeping some is a
    new feature rather than parity, and a bounded one, because a fight's history
    is not worth an unbounded blob. *)
val persisted_past : int

(** Reads {!storage_key}, falling back to the v1 keys, falling back to the
    shipped roster. Returns what it found and anything it had to repair or could
    not read, for a toast at startup. *)
val load : unit -> World.t * Normalization.t list * string option
