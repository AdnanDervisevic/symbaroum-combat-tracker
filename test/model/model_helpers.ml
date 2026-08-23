(** Fixtures for the model tests.

    A {!Symbaroum.Fighter.t} is built from a {!Symbaroum.Combatant.t}, which is
    the right dependency -- the model reads the domain and not the other way
    round -- but it makes a one-line fighter into a ten-line combatant. This is
    that ten lines, written once. *)

open! Core
open! Symbaroum
open Test_helpers

let fighter
      ?(order = 0)
      ?toughness
      ?defense
      ?armor
      ?pain_threshold
      ?prone
      ?flanked
      ?attributes
      ?attack
      ?(allegiance = Combatant.Allegiance.Non_player None)
      ~name
      ~initiative
      ()
  =
  Option.value_exn
    (Fighter.of_combatant
       (combatant
          ?toughness
          ?defense
          ?armor
          ?pain_threshold
          ?prone
          ?flanked
          ?attributes
          ?attack
          ~allegiance
          ~id:name
          ~name
          ~initiative
          ())
       ~order)
;;

(** A plain fighter with a weapon, for tests about the shape of a fight rather
    than about any particular statblock. *)
let plain
      ?order
      ?toughness
      ?defense
      ?(accurate = 12)
      ?(damage = "1d8")
      ?armor
      ?pain_threshold
      ?allegiance
      ~name
      ~initiative
      ()
  =
  fighter
    ?order
    ?toughness
    ?defense
    ?armor
    ?pain_threshold
    ?allegiance
    ~name
    ~initiative
    ~attack:(attack ~accurate ~damage ())
    ()
;;

let show_dp (r : Attrition_dp.result) =
  let low, high = r.p_bounds in
  printf
    "  p(party wins) %.6f  in [%.6f, %.6f]\n\
    \  expected casualties %.3f\n\
    \  %d states, %d rounds, residual %.2g\n"
    r.p_party_wins
    low
    high
    r.expected_party_casualties
    r.states
    r.rounds
    r.residual
;;

(** An encounter built straight from combatants, bypassing the roster: the model
    takes an {!Symbaroum.Encounter.t} and does not care how it was assembled. *)
let encounter_of members =
  let encounter, normalizations =
    Encounter.create ~members ~turn_index:0 ~round:1 ~name_counter:None
  in
  assert (
    List.is_empty
      (List.filter normalizations ~f:(function
         | Normalization.Name_counter_rebuilt _ -> false
         | _ -> true)));
  encounter
;;
