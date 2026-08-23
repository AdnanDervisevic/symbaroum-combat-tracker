open! Core

let budget = 250_000
let max_rounds = 200
let tolerance = 1e-9

(* [Float64] rather than a plain [float array] on purpose: js_of_ocaml maps a
   bigarray onto a [Float64Array] and a [float array] onto a boxed JS array, and
   this is the hot loop. *)
type buffer = (float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array1.t

let create_buffer n : buffer = Bigarray.Array1.create Float64 C_layout n

(* One side of the fight, and the arithmetic that turns [(member, toughness,
   prone)] into an integer and back.

   The encoding wastes a little space -- every member gets room for the largest
   starting toughness on its side, not its own -- in exchange for index
   arithmetic with no table lookup. At these sizes that is the right trade. *)
module Side = struct
  type t =
    { fighters : Fighter.t array
    ; height : int (** the largest starting toughness on this side *)
    ; live_states : int
    ; size : int
    }

  let create fighters =
    let height =
      Array.fold fighters ~init:1 ~f:(fun acc (f : Fighter.t) -> Int.max acc f.toughness)
    in
    let live_states = Array.length fighters * height * 2 in
    { fighters; height; live_states; size = live_states + 1 }
  ;;

  (* Every member dead. Absorbing, and the last index, so a loop over live states
     is simply [0 .. live_states - 1]. *)
  let wiped t = t.live_states

  let index t ~member ~toughness ~prone =
    (((member * t.height) + (toughness - 1)) * 2) + Bool.to_int prone
  ;;

  let member t state = state / (t.height * 2)
  let toughness t state = (state / 2 % t.height) + 1
  let prone (_ : t) state = state % 2 = 1
  let count t = Array.length t.fighters

  (** Where a member stands when it becomes the current target: at whatever it
      had when the question was asked, and on its feet. See the note in
      [doc/model.md] about prone combatants who are not the current target. *)
  let entering t member =
    if member >= count t
    then wiped t
    else index t ~member ~toughness:t.fighters.(member).toughness ~prone:false
  ;;

  let start t =
    if count t = 0
    then wiped t
    else index t ~member:0 ~toughness:t.fighters.(0).toughness ~prone:t.fighters.(0).prone
  ;;
end

(* What one attacker's blow does to the defending side's state, worked out once
   per (attacker, defender-state) pair rather than per iteration. The support is
   small -- a miss plus one entry per damage value -- so this is a few thousand
   floats for a realistic fight. *)
let outcomes_against ~(attacker : Fighter.t) ~(defender_side : Side.t) =
  Array.init defender_side.live_states ~f:(fun state ->
    let j = Side.member defender_side state in
    let h = Side.toughness defender_side state in
    let prone = Side.prone defender_side state in
    let defender = defender_side.fighters.(j) in
    let p_hit = Fighter.hit_chance attacker ~defender ~defender_prone:prone in
    let damage = Fighter.damage_against attacker ~defender in
    let outcomes = ref [ state, 1. -. p_hit ] in
    List.iter (Pmf.to_alist damage) ~f:(fun (rolled, p) ->
      (* The pain check uses the damage actually dealt, not the number rolled --
         a nine-point swing against three remaining toughness deals three. Same
         rule as [Combatant.hurt], and the reason [Toughness.damage] reports what
         it took. *)
      let dealt = Int.min rolled h in
      let prones = Pain_threshold.is_exceeded defender.pain_threshold ~damage:dealt in
      let next =
        if dealt >= h
        then Side.entering defender_side (j + 1)
        else
          Side.index
            defender_side
            ~member:j
            ~toughness:(h - dealt)
            ~prone:(prone || prones)
      in
      outcomes := (next, p_hit *. p) :: !outcomes);
    Array.of_list (List.filter !outcomes ~f:(fun (_, p) -> Float.(p > 0.))))
;;

(* One attacker's turn, applied to the whole distribution.

   Written once and used in both directions. [index] is what says which
   coordinate is the attacker's and which the defender's, so the two directions
   cannot drift apart the way two copies of this loop would. *)
let apply_attack
      ~(current : buffer)
      ~(scratch : buffer)
      ~(attacker_side : Side.t)
      ~(defender_side : Side.t)
      ~attacker
      ~outcomes
      ~index
  =
  Bigarray.Array1.fill scratch 0.;
  let add at p =
    Bigarray.Array1.unsafe_set scratch at (Bigarray.Array1.unsafe_get scratch at +. p)
  in
  for att = 0 to attacker_side.size - 1 do
    let attacker_dead_or_absorbed =
      att = Side.wiped attacker_side || attacker < Side.member attacker_side att
    in
    let standing_up =
      (not attacker_dead_or_absorbed)
      && attacker = Side.member attacker_side att
      && Side.prone attacker_side att
    in
    (* A combatant who is on the ground spends its action getting up. This is
       the only place the attacking side's own coordinate moves. *)
    let att_after =
      if standing_up
      then
        Side.index
          attacker_side
          ~member:attacker
          ~toughness:(Side.toughness attacker_side att)
          ~prone:false
      else att
    in
    for def = 0 to defender_side.size - 1 do
      let p = Bigarray.Array1.unsafe_get current (index ~att ~def) in
      if Float.(p > 0.)
      then
        if def = Side.wiped defender_side || attacker_dead_or_absorbed
        then
          (* Absorbed, or the attacker is dead: nothing moves at all. *)
          add (index ~att ~def) p
        else if standing_up
        then add (index ~att:att_after ~def) p
        else
          Array.iter outcomes.(def) ~f:(fun (def', q) ->
            add (index ~att ~def:def') (p *. q))
    done
  done
;;

type result =
  { p_party_wins : float
  ; p_bounds : float * float
  ; expected_party_casualties : float
  ; rounds : int
  ; residual : float
  ; states : int
  ; absorbed_after_round : float array
  }
[@@deriving sexp_of]

let state_count ~party ~foes = (Side.create party).size * (Side.create foes).size

let round_quantile t ~q =
  Array.findi t.absorbed_after_round ~f:(fun _ absorbed -> Float.(absorbed >= q))
  |> Option.map ~f:(fun (round, _) -> round + 1)
;;

let solve ~party ~foes =
  let a = Side.create party
  and b = Side.create foes in
  let size_b = b.size in
  let states = a.size * size_b in
  let index_party_attacking ~att ~def = (att * size_b) + def in
  let index_foes_attacking ~att ~def = (def * size_b) + att in
  let party_outcomes =
    Array.map party ~f:(fun attacker -> outcomes_against ~attacker ~defender_side:b)
  in
  let foe_outcomes =
    Array.map foes ~f:(fun attacker -> outcomes_against ~attacker ~defender_side:a)
  in
  (* Initiative order across both sides, ties broken by where the combatant sits
     in the encounter -- so the order the GM is looking at is the order the model
     uses, and a tie is not silently a bias towards the party. *)
  let turn_order =
    let entries =
      List.concat
        [ List.mapi (Array.to_list party) ~f:(fun i (f : Fighter.t) -> `Party, i, f)
        ; List.mapi (Array.to_list foes) ~f:(fun i (f : Fighter.t) -> `Foes, i, f)
        ]
    in
    List.sort entries ~compare:(fun (_, _, (x : Fighter.t)) (_, _, (y : Fighter.t)) ->
      match Int.descending x.initiative y.initiative with
      | 0 -> Int.ascending x.order y.order
      | c -> c)
    |> List.map ~f:(fun (side, i, _) -> side, i)
  in
  let current = ref (create_buffer states)
  and scratch = ref (create_buffer states) in
  Bigarray.Array1.fill !current 0.;
  Bigarray.Array1.set
    !current
    (index_party_attacking ~att:(Side.start a) ~def:(Side.start b))
    1.;
  let wiped_a = Side.wiped a
  and wiped_b = Side.wiped b in
  let party_wins () =
    let total = ref 0. in
    for att = 0 to a.live_states - 1 do
      total
      := !total +. Bigarray.Array1.get !current (index_party_attacking ~att ~def:wiped_b)
    done;
    !total
  in
  let party_wiped () =
    let total = ref 0. in
    for def = 0 to size_b - 1 do
      total
      := !total +. Bigarray.Array1.get !current (index_party_attacking ~att:wiped_a ~def)
    done;
    !total
  in
  let absorbed = Array.create ~len:max_rounds 0. in
  let rounds = ref 0 in
  let residual = ref 1. in
  let continue = ref true in
  while !continue do
    List.iter turn_order ~f:(fun (side, attacker) ->
      (match side with
       | `Party ->
         apply_attack
           ~current:!current
           ~scratch:!scratch
           ~attacker_side:a
           ~defender_side:b
           ~attacker
           ~outcomes:party_outcomes.(attacker)
           ~index:index_party_attacking
       | `Foes ->
         apply_attack
           ~current:!current
           ~scratch:!scratch
           ~attacker_side:b
           ~defender_side:a
           ~attacker
           ~outcomes:foe_outcomes.(attacker)
           ~index:index_foes_attacking);
      let swap = !current in
      current := !scratch;
      scratch := swap);
    let done_ = party_wins () +. party_wiped () in
    absorbed.(!rounds) <- done_;
    residual := Float.max 0. (1. -. done_);
    Int.incr rounds;
    if Float.(!residual < tolerance) || !rounds >= max_rounds then continue := false
  done;
  let p_party_wins = party_wins () in
  let expected_party_casualties =
    let total = ref 0. in
    for att = 0 to a.live_states - 1 do
      total
      := !total
         +. (Float.of_int (Side.member a att)
             *. Bigarray.Array1.get !current (index_party_attacking ~att ~def:wiped_b))
    done;
    total := !total +. (Float.of_int (Side.count a) *. party_wiped ());
    let absorbed_mass = p_party_wins +. party_wiped () in
    if Float.(absorbed_mass > 0.) then !total /. absorbed_mass else 0.
  in
  { p_party_wins
  ; p_bounds = p_party_wins, p_party_wins +. !residual
  ; expected_party_casualties
  ; rounds = !rounds
  ; residual = !residual
  ; states
  ; absorbed_after_round = Array.sub absorbed ~pos:0 ~len:!rounds
  }
;;
