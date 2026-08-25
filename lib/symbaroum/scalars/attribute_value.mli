(** An attribute score: the raw number on the character sheet, [1 .. 20]. *)

open! Core
include Bounded_int.S

(** [modifier t = 10 - to_int t]. *)
val modifier : t -> int
