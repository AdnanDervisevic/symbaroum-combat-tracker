(** The oracle, and what it says about the assumption the DP cannot drop.

    Two jobs here. The first table checks the exact method against a simulation
    of the same fight under matched assumptions -- that is the evidence that the
    index arithmetic in {!Symbaroum.Attrition_dp} means what it claims. The
    second measures the cost of focus fire instead of asserting it is small. *)

open! Core
open! Symbaroum
open Model_helpers

let seed = 20260823
let samples = 40_000

let cases =
  lazy
    [ ( "one on one"
      , [| plain ~name:"A" ~initiative:10 () |]
      , [| plain ~name:"B" ~initiative:1 () |] )
    ; ( "three on one, the one is big"
      , Array.init 3 ~f:(fun i ->
          plain ~order:i ~name:[%string "PC%{i#Int}"] ~initiative:10 ())
      , [| plain
             ~name:"Troll"
             ~initiative:9
             ~toughness:(Test_helpers.tough 24)
             ~accurate:14
             ~damage:"1d12"
             ~armor:(Armor.parse "3")
             ()
        |] )
    ; ( "two on four"
      , Array.init 2 ~f:(fun i ->
          plain
            ~order:i
            ~name:[%string "PC%{i#Int}"]
            ~initiative:12
            ~toughness:(Test_helpers.tough 14)
            ~accurate:13
            ())
      , Array.init 4 ~f:(fun i ->
          plain
            ~order:(10 + i)
            ~name:[%string "Goblin%{i#Int}"]
            ~initiative:8
            ~toughness:(Test_helpers.tough 8)
            ~accurate:9
            ~damage:"1d6"
            ()) )
    ; ( "pain thresholds on both sides"
      , Array.init 2 ~f:(fun i ->
          plain
            ~order:i
            ~name:[%string "PC%{i#Int}"]
            ~initiative:11
            ~toughness:(Test_helpers.tough 12)
            ~pain_threshold:(Pain_threshold.at_least 4)
            ())
      , Array.init 3 ~f:(fun i ->
          plain
            ~order:(10 + i)
            ~name:[%string "Wight%{i#Int}"]
            ~initiative:7
            ~toughness:(Test_helpers.tough 10)
            ~pain_threshold:(Pain_threshold.at_least 3)
            ~armor:(Armor.parse "1d4")
            ()) )
      (* Unequal starting toughness, which is the only way [Weakest_first] can
         differ from [Focus_in_order]: focusing in order makes the current target
         the weakest one anyway, so a side of identical members makes the two
         policies the same fight. Half this side is already hurt. *)
    ; ( "a foe line that is already hurt"
      , Array.init 2 ~f:(fun i ->
          plain
            ~order:i
            ~name:[%string "PC%{i#Int}"]
            ~initiative:11
            ~toughness:(Test_helpers.tough 12)
            ())
      , Array.init 4 ~f:(fun i ->
          plain
            ~order:(10 + i)
            ~name:[%string "Robber%{i#Int}"]
            ~initiative:8
            ~toughness:(Test_helpers.tough ~current:(if i % 2 = 0 then 2 else 11) 11)
            ~accurate:10
            ~damage:"1d6"
            ()) )
    ]
;;

(* Matched assumptions: same targeting, same hit chances, and damage drawn from
   the very same {!Pmf} the DP sums over. So a disagreement here is a
   disagreement about the fight, not about the weapon. *)
let%expect_test "the simulation agrees with the exact answer" =
  printf "  %-32s %8s %8s %8s %8s\n" "" "exact" "sampled" "diff" "4*se";
  List.iter (force cases) ~f:(fun (name, party, foes) ->
    let exact = Attrition_dp.solve ~party ~foes in
    let sampled = Combat_sim.run ~party ~foes ~targeting:Focus_in_order ~samples ~seed in
    let diff = Float.abs (exact.p_party_wins -. sampled.p_party_wins) in
    let bound = 4. *. sampled.stderr in
    printf
      "  %-32s %8.4f %8.4f %8.4f %8.4f %s\n"
      name
      exact.p_party_wins
      sampled.p_party_wins
      diff
      bound
      (if Float.(diff <= bound) then "ok" else "FAIL"));
  [%expect
    {|
                                        exact  sampled     diff     4*se
    one on one                         0.5755   0.5778   0.0023   0.0099 ok
    three on one, the one is big       0.3149   0.3148   0.0001   0.0093 ok
    two on four                        0.4966   0.4975   0.0009   0.0100 ok
    pain thresholds on both sides      0.0208   0.0201   0.0007   0.0028 ok
    a foe line that is already hurt    0.4144   0.4131   0.0013   0.0098 ok |}]
;;

let%expect_test "and on the casualties, which is the number a GM reads first" =
  printf "  %-32s %8s %8s\n" "" "exact" "sampled";
  List.iter (force cases) ~f:(fun (name, party, foes) ->
    let exact = Attrition_dp.solve ~party ~foes in
    let sampled = Combat_sim.run ~party ~foes ~targeting:Focus_in_order ~samples ~seed in
    printf
      "  %-32s %8.3f %8.3f\n"
      name
      exact.expected_party_casualties
      sampled.expected_party_casualties);
  [%expect
    {|
                                        exact  sampled
    one on one                          0.425    0.422
    three on one, the one is big        2.426    2.425
    two on four                         1.294    1.295
    pain thresholds on both sides       1.970    1.971
    a foe line that is already hurt     1.422    1.422 |}]
;;

(* The number that turns "focus fire is a reasonable assumption" into a claim
   with evidence behind it. Focus fire is the optimal attrition strategy for both
   sides, so assuming it symmetrically is an equilibrium assumption rather than a
   convenience -- but "the bias is small" is worth measuring rather than
   asserting. *)
let%expect_test "what focus fire costs: the same fights under three policies" =
  printf "  %-32s" "";
  List.iter Combat_sim.Targeting.all ~f:(fun t ->
    printf " %14s" (Sexp.to_string [%sexp (t : Combat_sim.Targeting.t)]));
  printf "\n";
  List.iter (force cases) ~f:(fun (name, party, foes) ->
    printf "  %-32s" name;
    List.iter Combat_sim.Targeting.all ~f:(fun targeting ->
      let r = Combat_sim.run ~party ~foes ~targeting ~samples ~seed in
      printf " %14.4f" r.p_party_wins);
    printf "\n");
  [%expect
    {|
                                     Focus_in_order Uniform_random  Weakest_first
    one on one                               0.5778         0.5798         0.5778
    three on one, the one is big             0.3148         0.3688         0.3148
    two on four                              0.4975         0.4988         0.4975
    pain thresholds on both sides            0.0201         0.0152         0.0201
    a foe line that is already hurt          0.4131         0.4240         0.5216 |}]
;;

(* And the number that forecloses the alternative. Under uniform targeting the
   state is the multiset of toughness values per side; multisets of 20 NPCs over
   11 values is C(30,10) before multiplying by the party side. The choice of
   focus fire was computed, not assumed. *)
let%expect_test "why the exact method cannot drop the assumption" =
  let rec choose n k = if k = 0 then 1 else choose (n - 1) (k - 1) * n / k in
  printf "  focus fire, 20 NPCs at T=10:      %d states\n" (20 * 10 * 2);
  printf "  uniform targeting, same side:     %d states\n" (choose 30 10);
  [%expect
    {|
    focus fire, 20 NPCs at T=10:      400 states
    uniform targeting, same side:     30045015 states |}]
;;

let%expect_test "a run reports its own reproducibility" =
  let _, party, foes = List.hd_exn (force cases) in
  let r = Combat_sim.run ~party ~foes ~targeting:Focus_in_order ~samples:20_000 ~seed in
  printf
    "  samples %d, seed %d, stderr %.5f, unresolved %d\n"
    r.samples
    seed
    r.stderr
    r.unresolved;
  printf
    "  mean rounds %.2f, median round %s\n"
    r.mean_rounds
    (Option.value_map (Combat_sim.round_quantile r ~q:0.5) ~default:"-" ~f:Int.to_string);
  [%expect
    {|
    samples 20000, seed 20260823, stderr 0.00349, unresolved 0
    mean rounds 3.42, median round 3 |}]
;;
