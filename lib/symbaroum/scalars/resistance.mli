(** A monster preset's difficulty band.

    Six values, not four: the plan for this port assumed [Weak], [Ordinary],
    [Challenging] and [Strong], but counting
    {{:src/data/defaultMonsters.ts} [defaultMonsters.ts]} finds [Mighty] (4
    presets) and [Legendary] (3) as well. That matters because {!Attack_profile}
    uses this band as the prior for a creature's damage die -- the app records no
    weapon data at all -- so a missing band would have silently defaulted seven
    of the nastiest creatures in the book to something mild. *)

open! Core

type t =
  | Weak
  | Ordinary
  | Challenging
  | Strong
  | Mighty
  | Legendary
[@@deriving enumerate, of_sexp, quickcheck]

include Identifiable.S_plain with type t := t
