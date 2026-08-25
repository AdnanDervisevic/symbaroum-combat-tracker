(** The one place a {!Symbaroum.World.t} is built from outside data. *)

open! Core

val to_domain : Wire_v2.t -> World.t * Normalization.t list

(** Total, and the inverse of {!to_domain} on anything {!to_domain} produced --
    which is the round-trip property, and the only thing holding the derived
    writer and the hand-written reader together. *)
val of_domain : World.t -> Wire_v2.t
