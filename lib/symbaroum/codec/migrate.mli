(** v1 forward into v2. Pure record shuffling: nothing here validates, clamps or reports, because {!Symbaroum.Domain_conv} does all of that once, for both versions, afterwards. *)

open! Core

val v1_to_v2 : Wire_v1.t -> Wire_v2.t
