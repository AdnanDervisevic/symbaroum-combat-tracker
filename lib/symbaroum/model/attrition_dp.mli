(** Exact absorption probability for a fight, by power iteration.

    {1 The reduction}

    The honest state of a fight is the whole toughness vector. Four player
    characters and six NPCs at 10 toughness each is [11^10 ≈ 2.6 × 10^10]
    states, which is not a computation, it is a wish.

    {b Under focus fire the vector collapses to two integers per side.} If each
    side attacks its enemies in a fixed order, then at any moment the enemies
    before the current target are dead and the ones after it are untouched -- at
    whatever toughness they had when the question was asked. So the party's
    entire state is [(i, h)]: the index of the first living member, and what that
    member has left. Symmetrically for the other side.

    Prone is nearly free. Only the current target can be knocked down, so it
    costs a factor of four rather than [2^(n_A + n_B)] -- which means the app's
    signature mechanic is modelled {i exactly} rather than dropped.

    {v
      state = (i, h_A, prone_A, j, h_B, prone_B)

      4 PCs (T=10)  vs  6 NPCs (T=10)        9,801 states
      5 PCs (T=15)  vs  8 NPCs (T=15)       36,391
      8 PCs (T=20)  vs 20 NPCs (T=20)      257,121   (over budget)
    v}

    Focus fire is the load-bearing assumption, and it is not free: see
    [doc/model.md], where {!Symbaroum.Combat_sim} is used to {i measure} the bias
    against two other targeting policies rather than assert it is small.

    {1 Within a round, resolution is exact}

    A round is the composition of one operator per combatant, in initiative
    order -- not a simultaneous approximation. Two things follow, and both are
    worth having. "Does a combatant that dies before its turn still act?" becomes
    a modelled fact rather than an artefact (it does not). And mutual
    annihilation cannot happen, so [p_party_wins + p_party_wiped = 1] exactly
    once the transient mass is gone.

    {1 Power iteration, and why the error bar is a proof}

    The alternative is solving [(I - Q)x = b], which wants BLAS. Avoiding it
    keeps this pure OCaml with zero C stubs, which is what lets the same code
    compile to JavaScript {i and} build anywhere -- a hard constraint, not a
    preference.

    The iteration also gives two things a linear solve does not. The distribution
    of fight lengths falls out for free, and "median 4 rounds, 90th percentile 9"
    is more use to a GM than a bare probability. And the error bar is rigorous:
    after [k] rounds the mass that has not yet been absorbed is an {i exact}
    upper bound on how far the answer can still move, so {!result.p_bounds} is a
    theorem rather than a heuristic. *)

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
