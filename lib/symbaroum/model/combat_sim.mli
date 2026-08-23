(** The same fight, sampled instead of summed.

    This is not a fallback that happens to also be a test. It has three distinct
    jobs, and the third is the one worth reading.

    {b It validates the DP.} Under matched assumptions -- same targeting, same
    hit chances, same damage distributions, drawn from the very same
    {!Symbaroum.Pmf} the DP sums over -- the two must agree to within sampling
    error. That is the check that the index arithmetic in
    {!Symbaroum.Attrition_dp} means what it claims.

    {b It handles fights the DP cannot.} Above
    {!Symbaroum.Attrition_dp.budget} states the exact method is too slow for a
    browser. Note the inversion: the DP's cost is quadratic in toughness and
    sampling's is independent of it, so the sampler is fastest exactly where the
    exact method becomes infeasible.

    {b It measures the cost of the assumption the DP cannot drop.} Focus fire is
    what makes exactness possible at all, and it is a real modelling choice
    rather than a fact about how people play. Because this simulator carries no
    state-space constraint it can run {!Targeting.Uniform_random} and
    {!Targeting.Weakest_first} as well, so [doc/model.md] can print the bias as a
    number instead of asserting it is small.

    Worth knowing why the DP cannot simply do the same: under uniform targeting
    the state is the {i multiset} of toughness values per side, and multisets of
    20 NPCs over 11 values is [C(30,10) ≈ 3 × 10^7] before multiplying by the
    other side. The choice of focus fire was computed, not assumed. *)

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
