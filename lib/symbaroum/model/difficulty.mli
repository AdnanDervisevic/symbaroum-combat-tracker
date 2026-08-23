(** How hard is this fight. *)

open! Core

module Label : sig
  type t =
    | Trivial
    | Easy
    | Balanced
    | Hard
    | Deadly
    | Overwhelming
  [@@deriving compare, equal, enumerate, sexp]

  (** [>= 0.95] Trivial, [0.85] Easy, [0.60] Balanced, [0.35] Hard, [0.15]
      Deadly, below that Overwhelming. Pinned at the boundaries by an expect
      test. *)
  val of_p_win : float -> t

  val to_string_hum : t -> string
end

module Method : sig
  type t =
    | Exact_dp of
        { states : int
        ; rounds : int
        ; residual : float
        }
    | Monte_carlo of
        { samples : int
        ; stderr : float
        ; seed : int
        }
  [@@deriving compare, equal, sexp]

  val to_string_hum : t -> string
end

type t =
  { label : Label.t
  ; p_party_wins : float
  ; p_bounds : float * float
  ; expected_party_casualties : float
  ; round_quantiles : (float * int) list (** [(0.5, 4); (0.9, 9)] *)
  ; method_ : Method.t
  ; caveats : Caveat.t list
    (** Everything the analysis had to guess, deduplicated across both sides.
          A number computed from an invented damage die is not the same kind of
          number as one computed from a statblock, and this is how the
          difference reaches the reader. *)
  }
[@@deriving compare, equal, sexp]

(** The seed used when none is given, so that the same encounter always produces
    the same number in the UI. *)
val default_seed : int

(** The quantiles reported: median and ninetieth percentile. *)
val quantiles : float list

(** [None] exactly when one side or the other has nobody left standing -- an
    encounter of four player characters and no enemies has no difficulty, and
    neither does an empty one. Combatants already at zero are not counted on
    either side. *)
val analyze : ?seed:int -> Encounter.t -> t option

(** One line, the way a GM should read it. *)
val to_string_hum : t -> string
