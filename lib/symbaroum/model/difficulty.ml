open! Core

let default_seed = 20260823
let quantiles = [ 0.5; 0.9 ]
let monte_carlo_samples = 20_000

module Label = struct
  type t =
    | Trivial
    | Easy
    | Balanced
    | Hard
    | Deadly
    | Overwhelming
  [@@deriving compare, equal, enumerate, sexp]

  let of_p_win p =
    if Float.(p >= 0.95)
    then Trivial
    else if Float.(p >= 0.85)
    then Easy
    else if Float.(p >= 0.60)
    then Balanced
    else if Float.(p >= 0.35)
    then Hard
    else if Float.(p >= 0.15)
    then Deadly
    else Overwhelming
  ;;

  let to_string_hum = function
    | Trivial -> "Trivial"
    | Easy -> "Easy"
    | Balanced -> "Balanced"
    | Hard -> "Hard"
    | Deadly -> "Deadly"
    | Overwhelming -> "Overwhelming"
  ;;
end

module Method = struct
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

  let to_string_hum = function
    | Exact_dp { states; rounds; residual } ->
      [%string
        "exact, over %{states#Int} states in %{rounds#Int} rounds (unresolved mass \
         %{residual#Float})"]
    | Monte_carlo { samples; stderr; seed } ->
      [%string
        "%{samples#Int} simulations, seed %{seed#Int}, standard error %{stderr#Float}"]
  ;;
end

type t =
  { label : Label.t
  ; p_party_wins : float
  ; p_bounds : float * float
  ; expected_party_casualties : float
  ; round_quantiles : (float * int) list
  ; method_ : Method.t
  ; caveats : Caveat.t list
  }
[@@deriving compare, equal, sexp]

(* Sides, in the encounter's own order, with the already-down left out: a
   combatant at zero is not in the fight, and counting one would make a wiped
   party look like a party. *)
let sides encounter =
  let fighters =
    List.filter_mapi (Encounter.members encounter) ~f:(fun order combatant ->
      Option.map (Fighter.of_combatant combatant ~order) ~f:(fun fighter ->
        Combatant.Allegiance.is_player combatant.allegiance, fighter))
  in
  let take is_player =
    List.filter_map fighters ~f:(fun (player, fighter) ->
      Option.some_if (Bool.equal player is_player) fighter)
    |> Array.of_list
  in
  take true, take false
;;

let analyze ?(seed = default_seed) encounter =
  let party, foes = sides encounter in
  if Array.is_empty party || Array.is_empty foes
  then None
  else (
    let caveats =
      Array.concat_map (Array.append party foes) ~f:(fun (f : Fighter.t) ->
        Array.of_list f.caveats)
      |> Array.to_list
      |> List.dedup_and_sort ~compare:Caveat.compare
    in
    let p_party_wins, p_bounds, expected_party_casualties, round_quantiles, method_ =
      if Attrition_dp.state_count ~party ~foes <= Attrition_dp.budget
      then (
        let r = Attrition_dp.solve ~party ~foes in
        ( r.p_party_wins
        , r.p_bounds
        , r.expected_party_casualties
        , List.filter_map quantiles ~f:(fun q ->
            Option.map (Attrition_dp.round_quantile r ~q) ~f:(fun round -> q, round))
        , Method.Exact_dp { states = r.states; rounds = r.rounds; residual = r.residual }
        ))
      else (
        let r =
          Combat_sim.run
            ~party
            ~foes
            ~targeting:Focus_in_order
            ~samples:monte_carlo_samples
            ~seed
        in
        ( r.p_party_wins
        , ( Float.max 0. (r.p_party_wins -. (2. *. r.stderr))
          , Float.min 1. (r.p_party_wins +. (2. *. r.stderr)) )
        , r.expected_party_casualties
        , List.filter_map quantiles ~f:(fun q ->
            Option.map (Combat_sim.round_quantile r ~q) ~f:(fun round -> q, round))
        , Method.Monte_carlo { samples = r.samples; stderr = r.stderr; seed } ))
    in
    Some
      { label = Label.of_p_win p_party_wins
      ; p_party_wins
      ; p_bounds
      ; expected_party_casualties
      ; round_quantiles
      ; method_
      ; caveats
      })
;;

let to_string_hum t =
  let percent = Float.iround_nearest_exn (t.p_party_wins *. 100.) in
  let rounds =
    match List.Assoc.find t.round_quantiles 0.5 ~equal:Float.equal with
    | None -> ""
    | Some median -> [%string ", median %{median#Int} rounds"]
  in
  let caveats =
    match List.length t.caveats with
    | 0 -> ""
    | n -> [%string " (%{n#Int} caveat(s))"]
  in
  let casualties = sprintf "%.1f" t.expected_party_casualties in
  [%string
    "%{Label.to_string_hum t.label} -- %{percent#Int}% win, expect %{casualties} \
     casualties%{rounds}%{caveats}"]
;;
