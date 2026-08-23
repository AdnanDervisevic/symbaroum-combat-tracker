(** The verdict a GM reads, and the properties that make it trustworthy. *)

open! Core
open! Symbaroum
open Expect_test_helpers_core
open Test_helpers
open Model_helpers

let%expect_test "the label boundaries, pinned" =
  List.iter
    [ 1.0
    ; 0.951
    ; 0.95
    ; 0.949
    ; 0.851
    ; 0.85
    ; 0.849
    ; 0.601
    ; 0.60
    ; 0.599
    ; 0.351
    ; 0.35
    ; 0.349
    ; 0.151
    ; 0.15
    ; 0.149
    ; 0.0
    ]
    ~f:(fun p ->
      printf
        "  %.3f  %s\n"
        p
        (Difficulty.Label.to_string_hum (Difficulty.Label.of_p_win p)));
  [%expect
    {|
    1.000  Trivial
    0.951  Trivial
    0.950  Trivial
    0.949  Easy
    0.851  Easy
    0.850  Easy
    0.849  Balanced
    0.601  Balanced
    0.600  Balanced
    0.599  Hard
    0.351  Hard
    0.350  Hard
    0.349  Deadly
    0.151  Deadly
    0.150  Deadly
    0.149  Overwhelming
    0.000  Overwhelming |}]
;;

(* [None] exactly when one side has nobody standing. An encounter of four player
   characters and no enemies has no difficulty, and neither does an empty one. *)
let%expect_test "a fight needs two sides" =
  let party =
    [ combatant
        ~allegiance:(Player_character (chid "ch_a"))
        ~id:"c1"
        ~name:"Ymma"
        ~initiative:10
        ()
    ]
  in
  let goblin =
    combatant
      ~allegiance:(Non_player (Some (mt "Goblin")))
      ~id:"c2"
      ~name:"Goblin 1"
      ~initiative:8
      ()
  in
  let show label members =
    printf
      "  %-24s %s\n"
      label
      (Option.value_map
         (Difficulty.analyze (encounter_of members))
         ~default:"(no verdict)"
         ~f:Difficulty.to_string_hum)
  in
  show "nobody" [];
  show "party only" party;
  show "foes only" [ goblin ];
  show "both" (party @ [ goblin ]);
  (* A combatant already at zero is not in the fight. *)
  show
    "party, but they are down"
    ({ (List.hd_exn party) with toughness = tough ~current:0 10 } :: [ goblin ]);
  [%expect
    {|
    nobody                   (no verdict)
    party only               (no verdict)
    foes only                (no verdict)
    both                     Hard -- 56% win, expect 0.4 casualties, median 4 rounds (1 caveat(s))
    party, but they are down (no verdict) |}]
;;

(* The ninth row of the bug ledger. [EncounterPanel.tsx:19] divides the NPC
   average defence by the party's, and with the two shipped characters whose
   notes read "Placeholder stats" the party's average rounds to zero -- so the
   heuristic returns [Infinity] with stock data. Two things stop that here:
   [Defense.t] cannot be zero, and nothing in the model is a ratio. *)
let%expect_test "test_difficulty_with_zero_defense_party" =
  let roster_pc name =
    let character =
      List.find_exn Default_roster.all ~f:(fun c ->
        String.equal (Name.to_string c.name) name)
    in
    Combatant.of_character character ~id:(cid [%string "cmb_%{name}"])
  in
  let members =
    [ roster_pc "Vigoi"
    ; roster_pc "Ymma"
    ; combatant
        ~allegiance:(Non_player (Some (mt "Goblin")))
        ~id:"g1"
        ~name:"Goblin 1"
        ~initiative:8
        ~toughness:(tough 8)
        ()
    ]
  in
  List.iter members ~f:(fun (c : Combatant.t) ->
    printf
      "  %-10s defence target %d\n"
      (Name.to_string c.name)
      (Defense.to_int c.defense));
  let analysis = Option.value_exn (Difficulty.analyze (encounter_of members)) in
  (* React: Infinity *)
  printf "  %s\n" (Difficulty.to_string_hum analysis);
  print_s [%sexp (analysis.method_ : Difficulty.Method.t)];
  List.iter analysis.caveats ~f:(fun c -> printf "  ! %s\n" (Caveat.to_string_hum c));
  [%expect
    {|
      Vigoi      defence target 10
      Ymma       defence target 10
      Goblin 1   defence target 10
      Trivial -- 100% win, expect 0.0 casualties, median 2 rounds (1 caveat(s))
    (Exact_dp
      (states   697)
      (rounds   28)
      (residual 7.5920070230495185E-10))
      ! No weapon recorded for this combatant; an average attack was assumed. |}]
;;

(* The shipped roster against preset monsters, which is the case the app is
   actually used for -- and the case where every attack on the party's side is
   invented, because the app records no weapons for anybody. The caveats are the
   point of the output, not a footnote. *)
let%expect_test "the shipped party against a preset, caveats and all" =
  let party =
    List.mapi Default_roster.all ~f:(fun i (c : Character.t) ->
      Combatant.of_character c ~id:(cid [%string "pc%{i#Int}"]))
  in
  let robbers =
    let draft = Npc_draft.of_preset (preset "Robber") in
    List.init 3 ~f:(fun i ->
      List.hd_exn
        (Npc_draft.to_combatants
           draft
           ~ids:[ cid [%string "r%{i#Int}"] ]
           ~names:[ name [%string "Robber %{(i + 1)#Int}"] ]))
  in
  let analysis = Option.value_exn (Difficulty.analyze (encounter_of (party @ robbers))) in
  printf "  %s\n" (Difficulty.to_string_hum analysis);
  printf "  method: %s\n" (Difficulty.Method.to_string_hum analysis.method_);
  List.iter analysis.round_quantiles ~f:(fun (q, round) ->
    printf "  %.0f%% of fights end by round %d\n" (q *. 100.) round);
  List.iter analysis.caveats ~f:(fun c -> printf "  ! %s\n" (Caveat.to_string_hum c));
  [%expect
    {|
    Trivial -- 99% win, expect 1.3 casualties, median 9 rounds (2 caveat(s))
    method: exact, over 5427 states in 54 rounds (unresolved mass 5.4737470112087294e-10)
    50% of fights end by round 9
    90% of fights end by round 15
    ! No weapon recorded; damage estimated from the Weak band.
    ! No weapon recorded for this combatant; an average attack was assumed. |}]
;;

(* Twelve encounters, printed as one table. This is the difficulty ladder a GM
   would actually recognise, and it is the thing to eyeball when the rules
   reconstruction changes. *)
let%expect_test "the difficulty ladder" =
  let row label party foes =
    let analysis = Option.value_exn (Difficulty.analyze (encounter_of (party @ foes))) in
    printf
      "  %-26s %-13s %5.1f%%  %4.1f casualties\n"
      label
      (Difficulty.Label.to_string_hum analysis.label)
      (analysis.p_party_wins *. 100.)
      analysis.expected_party_casualties
  in
  let party n ~toughness ~accurate ~damage =
    List.init n ~f:(fun i ->
      combatant
        ~allegiance:(Player_character (chid [%string "ch%{i#Int}"]))
        ~id:[%string "pc%{i#Int}"]
        ~name:[%string "PC%{i#Int}"]
        ~initiative:12
        ~toughness:(tough toughness)
        ~attack:(attack ~accurate ~damage ())
        ())
  in
  let foes n ~toughness ~accurate ~damage ~armor =
    List.init n ~f:(fun i ->
      combatant
        ~id:[%string "f%{i#Int}"]
        ~name:[%string "Foe%{i#Int}"]
        ~initiative:9
        ~toughness:(tough toughness)
        ~armor:(Armor.parse armor)
        ~attack:(attack ~accurate ~damage ())
        ())
  in
  let standard = party 4 ~toughness:10 ~accurate:12 ~damage:"1d8" in
  row "4 PC vs 1 weak" standard (foes 1 ~toughness:6 ~accurate:8 ~damage:"1d6" ~armor:"0");
  row "4 PC vs 2 weak" standard (foes 2 ~toughness:6 ~accurate:8 ~damage:"1d6" ~armor:"0");
  row "4 PC vs 4 weak" standard (foes 4 ~toughness:6 ~accurate:8 ~damage:"1d6" ~armor:"0");
  row
    "4 PC vs 4 even"
    standard
    (foes 4 ~toughness:10 ~accurate:12 ~damage:"1d8" ~armor:"0");
  row
    "4 PC vs 6 even"
    standard
    (foes 6 ~toughness:10 ~accurate:12 ~damage:"1d8" ~armor:"0");
  row
    "4 PC vs 8 even"
    standard
    (foes 8 ~toughness:10 ~accurate:12 ~damage:"1d8" ~armor:"0");
  row
    "4 PC vs 1 troll"
    standard
    (foes 1 ~toughness:30 ~accurate:15 ~damage:"1d12+2" ~armor:"4");
  row
    "4 PC vs 2 trolls"
    standard
    (foes 2 ~toughness:30 ~accurate:15 ~damage:"1d12+2" ~armor:"4");
  row
    "2 PC vs 4 even"
    (party 2 ~toughness:10 ~accurate:12 ~damage:"1d8")
    (foes 4 ~toughness:10 ~accurate:12 ~damage:"1d8" ~armor:"0");
  row
    "6 PC vs 4 even"
    (party 6 ~toughness:10 ~accurate:12 ~damage:"1d8")
    (foes 4 ~toughness:10 ~accurate:12 ~damage:"1d8" ~armor:"0");
  row
    "4 tough PC vs 6 even"
    (party 4 ~toughness:16 ~accurate:14 ~damage:"1d10")
    (foes 6 ~toughness:10 ~accurate:12 ~damage:"1d8" ~armor:"0");
  row
    "4 PC vs 4 armoured"
    standard
    (foes 4 ~toughness:10 ~accurate:12 ~damage:"1d8" ~armor:"4");
  [%expect
    {|
    4 PC vs 1 weak             Trivial       100.0%   0.0 casualties
    4 PC vs 2 weak             Trivial       100.0%   0.0 casualties
    4 PC vs 4 weak             Trivial        99.7%   0.4 casualties
    4 PC vs 4 even             Balanced       68.7%   2.3 casualties
    4 PC vs 6 even             Overwhelming    5.1%   3.9 casualties
    4 PC vs 8 even             Overwhelming    0.0%   4.0 casualties
    4 PC vs 1 troll            Overwhelming    6.2%   3.9 casualties
    4 PC vs 2 trolls           Overwhelming    0.0%   4.0 casualties
    2 PC vs 4 even             Overwhelming    0.8%   2.0 casualties
    6 PC vs 4 even             Trivial        99.7%   1.0 casualties
    4 tough PC vs 6 even       Balanced       68.5%   2.4 casualties
    4 PC vs 4 armoured         Overwhelming    0.2%   4.0 casualties |}]
;;

(* {1 Properties} *)

(* The theorem worth having: reinforcements never help the party. It is a genuine
   statement about the model rather than about any one fight, and it is the
   strongest bug-catcher in this directory -- an index slip in the DP breaks it
   almost immediately. *)
let%test_unit "adding a foe weakly decreases the party's chances" =
  Base_quickcheck.Test.run_exn
    (module struct
      type t = int * int * int * int [@@deriving quickcheck, sexp_of]
    end)
    ~f:(fun (n_party, toughness, accurate, foe_toughness) ->
      let n_party = 1 + (Int.abs n_party % 3) in
      let toughness = 4 + (Int.abs toughness % 10) in
      let accurate = 5 + (Int.abs accurate % 12) in
      let foe_toughness = 4 + (Int.abs foe_toughness % 10) in
      let party =
        Array.init n_party ~f:(fun i ->
          plain
            ~order:i
            ~name:[%string "PC%{i#Int}"]
            ~initiative:10
            ~toughness:(tough toughness)
            ~accurate
            ())
      in
      let foe i =
        plain
          ~order:(20 + i)
          ~name:[%string "F%{i#Int}"]
          ~initiative:5
          ~toughness:(tough foe_toughness)
          ~accurate:10
          ()
      in
      let with_one = (Attrition_dp.solve ~party ~foes:[| foe 0 |]).p_party_wins in
      let with_two = (Attrition_dp.solve ~party ~foes:[| foe 0; foe 1 |]).p_party_wins in
      [%test_pred: float * float]
        (fun (with_one, with_two) -> Float.(with_two <= with_one + 1e-9))
        (with_one, with_two))
;;

let%test_unit "a tougher foe weakly decreases the party's chances" =
  Base_quickcheck.Test.run_exn
    (module struct
      type t = int * int * int [@@deriving quickcheck, sexp_of]
    end)
    ~f:(fun (n_party, accurate, foe_toughness) ->
      let n_party = 1 + (Int.abs n_party % 3) in
      let accurate = 5 + (Int.abs accurate % 12) in
      let foe_toughness = 4 + (Int.abs foe_toughness % 10) in
      let party =
        Array.init n_party ~f:(fun i ->
          plain ~order:i ~name:[%string "PC%{i#Int}"] ~initiative:10 ~accurate ())
      in
      let foes toughness =
        [| plain ~order:20 ~name:"F" ~initiative:5 ~toughness:(tough toughness) () |]
      in
      let weaker = (Attrition_dp.solve ~party ~foes:(foes foe_toughness)).p_party_wins in
      let stronger =
        (Attrition_dp.solve ~party ~foes:(foes (foe_toughness + 3))).p_party_wins
      in
      [%test_pred: float * float]
        (fun (weaker, stronger) -> Float.(stronger <= weaker +. 1e-9))
        (weaker, stronger))
;;

let%test_unit "a more accurate foe weakly decreases the party's chances" =
  Base_quickcheck.Test.run_exn
    (module struct
      type t = int * int * int [@@deriving quickcheck, sexp_of]
    end)
    ~f:(fun (n_party, party_accurate, foe_accurate) ->
      let n_party = 1 + (Int.abs n_party % 3) in
      let party_accurate = 5 + (Int.abs party_accurate % 12) in
      let foe_accurate = 3 + (Int.abs foe_accurate % 12) in
      let party =
        Array.init n_party ~f:(fun i ->
          plain
            ~order:i
            ~name:[%string "PC%{i#Int}"]
            ~initiative:10
            ~accurate:party_accurate
            ())
      in
      let foes accurate =
        [| plain ~order:20 ~name:"F" ~initiative:5 ~toughness:(tough 12) ~accurate () |]
      in
      let dull = (Attrition_dp.solve ~party ~foes:(foes foe_accurate)).p_party_wins in
      let sharp =
        (Attrition_dp.solve ~party ~foes:(foes (foe_accurate + 4))).p_party_wins
      in
      [%test_pred: float * float]
        (fun (dull, sharp) -> Float.(sharp <= dull +. 1e-9))
        (dull, sharp))
;;

let%test_unit "the answer is always a probability, and the bounds always contain it" =
  Base_quickcheck.Test.run_exn
    (module struct
      type t = int * int * int * int [@@deriving quickcheck, sexp_of]
    end)
    ~f:(fun (n_party, n_foes, toughness, accurate) ->
      let n_party = 1 + (Int.abs n_party % 4) in
      let n_foes = 1 + (Int.abs n_foes % 4) in
      let toughness = 3 + (Int.abs toughness % 12) in
      let accurate = 3 + (Int.abs accurate % 15) in
      let side n offset initiative =
        Array.init n ~f:(fun i ->
          plain
            ~order:(offset + i)
            ~name:[%string "f%{(offset + i)#Int}"]
            ~initiative
            ~toughness:(tough toughness)
            ~accurate
            ())
      in
      let r = Attrition_dp.solve ~party:(side n_party 0 10) ~foes:(side n_foes 20 5) in
      let low, high = r.p_bounds in
      [%test_pred: Attrition_dp.result]
        (fun (r : Attrition_dp.result) ->
           Float.(r.p_party_wins >= 0. && r.p_party_wins <= 1.)
           && Float.(low <= r.p_party_wins && r.p_party_wins <= high)
           && Float.(r.expected_party_casualties >= 0.)
           && Float.(r.expected_party_casualties <= Float.of_int n_party))
        r)
;;
