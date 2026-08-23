open! Core

module Targeting = struct
  type t =
    | Focus_in_order
    | Uniform_random
    | Weakest_first
  [@@deriving compare, equal, enumerate, sexp_of]

  let to_string_hum = function
    | Focus_in_order -> "focus fire, in encounter order"
    | Uniform_random -> "a living enemy at random"
    | Weakest_first -> "the weakest living enemy"
  ;;
end

type result =
  { p_party_wins : float
  ; stderr : float
  ; expected_party_casualties : float
  ; mean_rounds : float
  ; unresolved : int
  ; samples : int
  ; rounds_histogram : int array
  }
[@@deriving sexp_of]

(* The mutable half of one simulated fight. Allocated once per [run] and reset
   per sample, so a twenty-thousand-sample run does not spend its time in the
   allocator. *)
type side =
  { fighters : Fighter.t array
  ; toughness : int array
  ; prone : bool array
  ; mutable living : int
  }

let create_side fighters =
  { fighters
  ; toughness = Array.create ~len:(Array.length fighters) 0
  ; prone = Array.create ~len:(Array.length fighters) false
  ; living = 0
  }
;;

let reset side =
  Array.iteri side.fighters ~f:(fun i (f : Fighter.t) ->
    side.toughness.(i) <- f.toughness;
    side.prone.(i) <- f.prone);
  side.living <- Array.length side.fighters
;;

let choose_target side ~targeting random =
  match (targeting : Targeting.t) with
  | Focus_in_order ->
    Array.findi side.toughness ~f:(fun _ t -> t > 0) |> Option.map ~f:fst
  | Weakest_first ->
    Array.foldi side.toughness ~init:None ~f:(fun i best t ->
      if t <= 0
      then best
      else (
        match best with
        | Some (_, best_t) when best_t <= t -> best
        | _ -> Some (i, t)))
    |> Option.map ~f:fst
  | Uniform_random ->
    if side.living = 0
    then None
    else (
      let nth = Splittable_random.int random ~lo:0 ~hi:(side.living - 1) in
      let rec go i seen =
        if side.toughness.(i) > 0
        then if seen = nth then Some i else go (i + 1) (seen + 1)
        else go (i + 1) seen
      in
      go 0 0)
;;

let strike ~(attacker : Fighter.t) ~defenders ~target ~targeting:_ random =
  let defender = defenders.fighters.(target) in
  let p_hit =
    Fighter.hit_chance attacker ~defender ~defender_prone:defenders.prone.(target)
  in
  if Float.(Splittable_random.float random ~lo:0. ~hi:1. >= p_hit)
  then ()
  else (
    (* Sampled from the same [Pmf] the DP sums over, so a disagreement between
       the two is a disagreement about the fight and not about the weapon. *)
    let rolled = Pmf.sample (Fighter.damage_against attacker ~defender) random in
    let dealt = Int.min rolled defenders.toughness.(target) in
    defenders.toughness.(target) <- defenders.toughness.(target) - dealt;
    if Pain_threshold.is_exceeded defender.pain_threshold ~damage:dealt
    then defenders.prone.(target) <- true;
    if defenders.toughness.(target) <= 0 then defenders.living <- defenders.living - 1)
;;

let run ~party ~foes ~targeting ~samples ~seed =
  let a = create_side party
  and b = create_side foes in
  let turn_order =
    List.concat
      [ List.mapi (Array.to_list party) ~f:(fun i (f : Fighter.t) -> `Party, i, f)
      ; List.mapi (Array.to_list foes) ~f:(fun i (f : Fighter.t) -> `Foes, i, f)
      ]
    |> List.sort ~compare:(fun (_, _, (x : Fighter.t)) (_, _, (y : Fighter.t)) ->
      match Int.descending x.initiative y.initiative with
      | 0 -> Int.ascending x.order y.order
      | c -> c)
    |> List.map ~f:(fun (side, i, _) -> side, i)
  in
  let random = Splittable_random.State.of_int seed in
  let wins = ref 0
  and casualties = ref 0
  and rounds_total = ref 0
  and unresolved = ref 0 in
  let rounds_histogram = Array.create ~len:(Attrition_dp.max_rounds + 1) 0 in
  for _ = 1 to samples do
    reset a;
    reset b;
    let round = ref 0 in
    while a.living > 0 && b.living > 0 && !round < Attrition_dp.max_rounds do
      Int.incr round;
      List.iter turn_order ~f:(fun (side, i) ->
        if a.living > 0 && b.living > 0
        then (
          let attackers, defenders =
            match side with
            | `Party -> a, b
            | `Foes -> b, a
          in
          if attackers.toughness.(i) > 0
          then
            if attackers.prone.(i)
            then attackers.prone.(i) <- false (* spends the action getting up *)
            else (
              match choose_target defenders ~targeting random with
              | None -> ()
              | Some target ->
                strike
                  ~attacker:attackers.fighters.(i)
                  ~defenders
                  ~target
                  ~targeting
                  random)))
    done;
    rounds_total := !rounds_total + !round;
    rounds_histogram.(!round) <- rounds_histogram.(!round) + 1;
    casualties
    := !casualties + Array.count a.toughness ~f:(fun toughness -> toughness <= 0);
    if b.living = 0 && a.living > 0
    then Int.incr wins
    else if a.living > 0 && b.living > 0
    then Int.incr unresolved
  done;
  let n = Float.of_int samples in
  let p = Float.of_int !wins /. n in
  { p_party_wins = p
  ; stderr = Float.sqrt (p *. (1. -. p) /. n)
  ; expected_party_casualties = Float.of_int !casualties /. n
  ; mean_rounds = Float.of_int !rounds_total /. n
  ; unresolved = !unresolved
  ; samples
  ; rounds_histogram
  }
;;

let round_quantile t ~q =
  let wanted = q *. Float.of_int t.samples in
  let seen = ref 0 in
  Array.findi t.rounds_histogram ~f:(fun _ count ->
    seen := !seen + count;
    Float.(Float.of_int !seen >= wanted))
  |> Option.map ~f:fst
;;
