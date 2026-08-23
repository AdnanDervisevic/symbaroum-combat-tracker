(** The exact DP, checked against closed forms before it is trusted on anything
    interesting.

    A dynamic program over ten thousand states is not something a reader can
    eyeball, so the first four tests are cases where the answer can be written
    down by hand. Everything after that rests on them. *)

open! Core
open! Symbaroum
open Test_helpers
open Model_helpers

let show = show_dp

(* Everything about this one is computable by hand. Two fighters, each of whom
   kills on any hit. The party swings first, so

     p_win = p / (1 - (1 - p)(1 - q))

   and with a clamped target of 19 both p and q are 0.95, giving
   0.95 / (1 - 0.0025) = 0.952380... The DP has no business disagreeing. *)
let%expect_test "one against one, both lethal: the closed form" =
  let lethal = attack ~accurate:20 ~damage:"10d10" () in
  let party =
    [| fighter ~name:"A" ~initiative:10 ~attack:lethal ~toughness:(tough 5) () |]
  and foes =
    [| fighter ~name:"B" ~initiative:1 ~attack:lethal ~toughness:(tough 5) () |]
  in
  let result = Attrition_dp.solve ~party ~foes in
  show result;
  let p = 19. /. 20. in
  printf "  closed form          %.6f\n" (p /. (1. -. ((1. -. p) *. (1. -. p))));
  [%expect
    {|
    p(party wins) 0.952381  in [0.952381, 0.952381]
    expected casualties 0.048
    121 states, 4 rounds, residual 3.9e-11
    closed form          0.952381 |}]
;;

(* An enemy who cannot get through the party's armour can never win, so the
   answer is exactly one -- and it is the test that [Pmf.sub_clamped] really does
   floor at zero rather than letting a negative through. *)
let%expect_test "an enemy who cannot hurt you loses with probability one" =
  let party =
    [| fighter
         ~name:"A"
         ~initiative:10
         ~attack:(attack ~accurate:15 ~damage:"1d6" ())
         ~armor:(Armor.parse "10")
         ~toughness:(tough 10)
         ()
    |]
  and foes =
    [| fighter
         ~name:"B"
         ~initiative:1
         ~attack:(attack ~accurate:15 ~damage:"1d4" ())
         ~toughness:(tough 10)
         ()
    |]
  in
  show (Attrition_dp.solve ~party ~foes);
  [%expect
    {|
    p(party wins) 1.000000  in [1.000000, 1.000000]
    expected casualties 0.000
    441 states, 25 rounds, residual 6.6e-10 |}]
;;

(* Mirror images, decided entirely by who swings first. The two numbers must sum
   to exactly one: within-round resolution is sequential, so a combatant who dies
   before its turn does not act, and mutual annihilation cannot happen. *)
let%expect_test "identical fighters: acting first is the whole advantage" =
  let make ~name ~initiative =
    fighter
      ~name
      ~initiative
      ~attack:(attack ~accurate:12 ~damage:"1d8" ())
      ~toughness:(tough 10)
      ()
  in
  let first =
    Attrition_dp.solve
      ~party:[| make ~name:"A" ~initiative:10 |]
      ~foes:[| make ~name:"B" ~initiative:1 |]
  in
  let second =
    Attrition_dp.solve
      ~party:[| make ~name:"A" ~initiative:1 |]
      ~foes:[| make ~name:"B" ~initiative:10 |]
  in
  printf "  party goes first: %.6f\n" first.p_party_wins;
  printf "  party goes second: %.6f\n" second.p_party_wins;
  printf "  sum: %.9f\n" (first.p_party_wins +. second.p_party_wins);
  [%expect
    {|
    party goes first: 0.575469
    party goes second: 0.424531
    sum: 0.999999999 |}]
;;

(* Four against one, and the four cannot lose without dying one at a time. *)
let%expect_test "numbers tell, and casualties are counted" =
  let pc i =
    fighter
      ~order:i
      ~name:[%string "PC%{i#Int}"]
      ~initiative:10
      ~attack:(attack ~accurate:11 ~damage:"1d8" ())
      ~toughness:(tough 10)
      ()
  in
  let troll =
    fighter
      ~order:9
      ~name:"Troll"
      ~initiative:9
      ~attack:(attack ~accurate:15 ~damage:"1d12+2" ())
      ~toughness:(tough 30)
      ~armor:(Armor.parse "4")
      ()
  in
  show (Attrition_dp.solve ~party:(Array.init 4 ~f:pc) ~foes:[| troll |]);
  [%expect
    {|
    p(party wins) 0.041208  in [0.041208, 0.041208]
    expected casualties 3.921
    4941 states, 29 rounds, residual 6.9e-10 |}]
;;

(* The pain threshold is the app's signature mechanic, and the reduction models
   it exactly rather than dropping it: only the current target can be knocked
   down, so it costs a factor of four in the state space and nothing in
   fidelity. A threshold of 1 makes every landed blow cost the victim its next
   action. *)
let%expect_test "a pain threshold is worth a real amount" =
  let make ?pain_threshold ~name ~initiative () =
    fighter
      ?pain_threshold
      ~name
      ~initiative
      ~attack:(attack ~accurate:12 ~damage:"1d8" ())
      ~toughness:(tough 12)
      ()
  in
  let without =
    Attrition_dp.solve
      ~party:[| make ~name:"A" ~initiative:10 () |]
      ~foes:[| make ~name:"B" ~initiative:1 () |]
  in
  let glass_jawed_foe =
    Attrition_dp.solve
      ~party:[| make ~name:"A" ~initiative:10 () |]
      ~foes:
        [| make ~name:"B" ~initiative:1 ~pain_threshold:(Pain_threshold.at_least 1) () |]
  in
  printf "  no thresholds:            %.6f\n" without.p_party_wins;
  printf "  foe prones on any hit:    %.6f\n" glass_jawed_foe.p_party_wins;
  [%expect
    {|
    no thresholds:            0.565703
    foe prones on any hit:    0.826960 |}]
;;

let%expect_test "how long the fight takes" =
  let make ~name ~initiative =
    fighter
      ~name
      ~initiative
      ~attack:(attack ~accurate:10 ~damage:"1d8" ())
      ~toughness:(tough 20)
      ()
  in
  let result =
    Attrition_dp.solve
      ~party:[| make ~name:"A" ~initiative:10 |]
      ~foes:[| make ~name:"B" ~initiative:1 |]
  in
  List.iter [ 0.10; 0.50; 0.90; 0.99 ] ~f:(fun q ->
    printf
      "  %d%% of fights are over by round %s\n"
      (Float.iround_nearest_exn (q *. 100.))
      (Option.value_map
         (Attrition_dp.round_quantile result ~q)
         ~default:"(never)"
         ~f:Int.to_string));
  [%expect
    {|
    10% of fights are over by round 5
    50% of fights are over by round 7
    90% of fights are over by round 11
    99% of fights are over by round 15 |}]
;;

let%expect_test "the state count is what the interface claims" =
  let make ~toughness i =
    fighter
      ~order:i
      ~name:[%string "f%{i#Int}"]
      ~initiative:1
      ~toughness:(tough toughness)
      ()
  in
  List.iter
    [ 4, 10, 6, 10; 5, 15, 8, 15; 8, 20, 20, 20 ]
    ~f:(fun (n_party, t_party, n_foes, t_foes) ->
      let party = Array.init n_party ~f:(make ~toughness:t_party) in
      let foes = Array.init n_foes ~f:(make ~toughness:t_foes) in
      printf
        "  %d PCs (T=%d) vs %d NPCs (T=%d): %d states%s\n"
        n_party
        t_party
        n_foes
        t_foes
        (Attrition_dp.state_count ~party ~foes)
        (if Attrition_dp.state_count ~party ~foes > Attrition_dp.budget
         then "  (over budget: Monte Carlo)"
         else ""));
  [%expect
    {|
    4 PCs (T=10) vs 6 NPCs (T=10): 9801 states
    5 PCs (T=15) vs 8 NPCs (T=15): 36391 states
    8 PCs (T=20) vs 20 NPCs (T=20): 257121 states  (over budget: Monte Carlo) |}]
;;
