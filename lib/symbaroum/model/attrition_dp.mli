(** Exact absorption probability for a fight, by power iteration.

    Under focus fire the toughness vector collapses to two integers per side:
    the enemies before the current target are dead and the ones after it are
    untouched. That takes 4 PCs against 6 NPCs from [11^10] states to 9,801.

    {v state = (i, h_A, prone_A, j, h_B, prone_B) v}

    The reduction, its assumptions, and what focus fire costs are derived in
    [doc/model.md]. *)

open! Core

(** Above this many states, {!solve} is too slow for a browser and
    {!Symbaroum.Difficulty} switches to Monte Carlo. Note the pleasing inversion:
    the DP's cost is quadratic in toughness and Monte Carlo's is independent of
    it, so sampling is fastest exactly where the exact method is infeasible. *)
val budget : int

val state_count : party:Fighter.t array -> foes:Fighter.t array -> int

(** When the iteration gives up rather than converging. *)
val max_rounds : int

(** Unabsorbed mass below this counts as converged. *)
val tolerance : float

type result =
  { p_party_wins : float
  ; p_bounds : float * float
    (** [(p, p + residual)]. The width is the unabsorbed mass, which is an
          exact bound on how far the answer could still move. *)
  ; expected_party_casualties : float
    (** Party members reduced to zero, in expectation, conditional on the
          fight ending. Lead a UI with this rather than with a probability:
          parties rarely fight to the last member. *)
  ; rounds : int
  ; residual : float
  ; states : int
  ; absorbed_after_round : float array
    (** Cumulative probability that the fight is over by the end of round
          [k+1]. This is where {!round_quantile} reads. *)
  }
[@@deriving sexp_of]

(** The first round by which the fight is over with probability at least [q].
    [None] if the iteration never got that far. *)
val round_quantile : result -> q:float -> int option

(** Both sides must be non-empty; {!Symbaroum.Difficulty} is what checks. *)
val solve : party:Fighter.t array -> foes:Fighter.t array -> result
