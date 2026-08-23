(** A range-checked integer, for the several scalars in this domain that are
    "an [int], but only these ones".

    Four such types exist here ({!Symbaroum.Attribute_value},
    {!Symbaroum.Defense}, {!Symbaroum.Npc_count}, {!Symbaroum.Adjust_amount})
    and all four are bare [number] in the React app, where the bound lives in
    whichever call site last remembered it: [Math.max(0, Math.min(999, ...))] in
    [applyAdjustment] ({{:src/App.tsx} [App.tsx:398]}), [NPC_COUNT_MIN] and
    [NPC_COUNT_MAX] in the add dialog only, and nowhere at all on the import
    path. Here the bound is a property of the type, so there is exactly one
    place to check it and no way to skip it. *)

open! Core

module type S = sig
  type t = private int [@@deriving compare, equal, hash, sexp_of, quickcheck]

  val min_value : int
  val max_value : int

  (** The only total way in. *)
  val of_int : int -> t Or_error.t

  val of_int_exn : int -> t

  (** Saturating. The import path uses this and {i reports} the repair as a
      normalization; nothing else should reach for it. *)
  val of_int_clamped : int -> t

  val to_int : t -> int
end

module type Arg = sig
  val module_name : string
  val min_value : int
  val max_value : int
end

module Make (_ : Arg) : S
