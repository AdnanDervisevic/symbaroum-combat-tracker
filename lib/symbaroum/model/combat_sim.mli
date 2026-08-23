(** The same fight, sampled instead of summed. *)

open! Core

module Targeting : sig
  type t =
    | Focus_in_order
    (** Everyone attacks the first living enemy in the encounter's order.
            This is what {!Symbaroum.Attrition_dp} assumes, and it is the optimal
            attrition strategy for both sides -- so assuming it symmetrically is
            an equilibrium assumption rather than a convenience. *)
    | Uniform_random (** A living enemy at random. *)
    | Weakest_first (** The living enemy with the least toughness left. *)
  [@@deriving compare, equal, enumerate, sexp_of]

  val to_string_hum : t -> string
end

type result =
  { p_party_wins : float
  ; stderr : float (** of {!p_party_wins}; the usual [sqrt (p (1-p) / n)] *)
  ; expected_party_casualties : float
  ; mean_rounds : float
  ; unresolved : int
    (** Fights still going at {!Symbaroum.Attrition_dp.max_rounds}, counted as
          neither a win nor a loss. Reported rather than swept up, because a
          non-zero value means the estimate is biased and the reader should know
          by how much. *)
  ; samples : int
  ; rounds_histogram : int array
    (** How many samples ended in round [k]. Present so that a Monte Carlo
          result can answer the same "by which round is it over" question the
          exact method answers, and the two are interchangeable in a report. *)
  }
[@@deriving sexp_of]

(** The seed is an argument and never a default, so a printed number can always
    be reproduced. *)
val run
  :  party:Fighter.t array
  -> foes:Fighter.t array
  -> targeting:Targeting.t
  -> samples:int
  -> seed:int
  -> result

(** The first round by which the fight is over in at least [q] of the samples.
    The counterpart of {!Symbaroum.Attrition_dp.round_quantile}. *)
val round_quantile : result -> q:float -> int option
