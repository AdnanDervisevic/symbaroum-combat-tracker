(** How hard is this fight.

    This replaces the heuristic at
    {{:src/components/panels/EncounterPanel.tsx} [EncounterPanel.tsx:5-35]},
    whose weights -- 0.5, 0.3, 0.2 over a toughness ratio, a defence ratio and a
    headcount ratio -- are derived from nothing, and whose defence ratio divides
    by the party's average defence. That average is zero for a party of the two
    shipped characters whose stats are placeholders, so the heuristic returns
    [Infinity] with stock data.

    {1 Lead with the casualties, not the probability}

    Parties do not fight to the last member; they retreat, or they lose someone
    and the fight changes. So {!expected_party_casualties} is the number to put
    in front of a GM, and {!Label.t} is the summary. "Balanced -- 71% win, expect
    1.3 casualties, median 5 rounds" is a sentence a GM can act on; a bare label
    is not.

    {1 Two methods, one type}

    Small fights are solved exactly and large ones are sampled, and
    {!Method.t} says which happened, with the numbers needed to judge it: the
    state count and the residual for the exact method, the sample count, standard
    error and {b seed} for the sampled one. A printed result is always
    reproducible.

    The labels are deliberately {i not} calibrated against the old heuristic.
    Continuity with a broken baseline is not a goal. *)

open! Core

module Label : sig
  type t =
    | Trivial
    | Easy
    | Balanced
    | Hard
    | Deadly
    | Overwhelming
  [@@deriving compare, equal, enumerate, sexp_of]

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
  [@@deriving compare, equal, sexp_of]

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
[@@deriving sexp_of]

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
