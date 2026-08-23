open! Core
open Expect_test_helpers_core

(* The golden dump the plan asked for: all 86 shipped presets, normalized, in one
   expectation. Its job is to make the Defense reconciliation a reviewable diff.
   The [def] column reads "stored -> target (how)", so a preset whose stored
   number could not be used as a modifier shows the substitution on its own line
   rather than disappearing into a summary. *)

let reduction_to_string : Symbaroum.Armor.Reduction.t option -> string = function
  | None -> "unparsed"
  | Some Unarmored -> "0"
  | Some (Fixed n) -> Int.to_string n
  | Some (Rolled dice) -> Symbaroum.Dice.to_string dice
;;

let pain_to_string (t : Symbaroum.Pain_threshold.t) =
  match t with
  | No_threshold -> "never"
  | Every_hit -> "any"
  | At_least n -> Int.to_string n
;;

let reading_to_string : Symbaroum.Monster_preset.Defense_reading.t -> string = function
  | Stored_modifier -> "mod"
  | Derived_from_quick -> "qui"
  | Unknown -> "???"
;;

let row (p : Symbaroum.Monster_preset.t) =
  let opt_int = Option.value_map ~default:"--" ~f:Int.to_string in
  printf
    "%-34s %-12s T%-4s def %4s -> %-4s (%s)  arm %-8s pain %-5s %s\n"
    (Symbaroum.Monster_type.to_string p.name)
    (Symbaroum.Resistance.to_string p.resistance)
    (Option.value_map p.toughness ~default:"--" ~f:(fun t -> Int.to_string t.max))
    (opt_int p.defense_raw)
    (Option.value_map p.defense ~default:"--" ~f:(fun d ->
       Int.to_string (Symbaroum.Defense.to_int d)))
    (reading_to_string p.defense_reading)
    (reduction_to_string p.armor.reduction)
    (pain_to_string p.pain_threshold)
    (Option.value_map p.attack ~default:"no attack" ~f:(fun a ->
       [%string
         "acc %{Symbaroum.Attribute_value.to_int a.accurate#Int} \
          %{Symbaroum.Dice.to_string a.damage}"]))
;;

let%expect_test "every shipped preset normalizes" =
  print_s [%message "" ~presets:(List.length Symbaroum.Monster_presets.all : int)];
  [%expect {| (presets 86) |}]
;;

let%expect_test "the Defense reconciliation, in aggregate" =
  let count f = List.count Symbaroum.Monster_presets.all ~f in
  let readings =
    List.map Symbaroum.Monster_preset.Defense_reading.all ~f:(fun reading ->
      ( reading
      , count (fun p ->
          Symbaroum.Monster_preset.Defense_reading.equal p.defense_reading reading) ))
  in
  print_s
    [%message
      ""
        (readings : (Symbaroum.Monster_preset.Defense_reading.t * int) list)
        ~no_toughness:(count (fun p -> Option.is_none p.toughness) : int)
        ~unparsed_armor:(count (fun p -> Symbaroum.Armor.is_unparsed p.armor) : int)
        ~no_attack:(count (fun p -> Option.is_none p.attack) : int)
        ~modellable:(List.length Symbaroum.Monster_presets.modellable : int)];
  [%expect
    {|
    ((readings (
       (Stored_modifier    74)
       (Derived_from_quick 12)
       (Unknown            0)))
     (no_toughness   7)
     (unparsed_armor 0)
     (no_attack      0)
     (modellable     79)) |}]
;;

(* Worth reading closely. For three of these five the substitution is a no-op --
   stored and target are the same number -- because those presets store the
   absolute target and [Defense.of_quick] recovers exactly that. Kvarek and Niha
   are off by two in opposite directions, which is transcription noise rather
   than a third convention. So the ruling costs almost nothing even where the
   stored field had to be discarded. *)
let%expect_test "the five presets that store an absolute target, not a modifier" =
  List.filter Symbaroum.Monster_presets.all ~f:(fun p ->
    match p.defense_reading with
    | Derived_from_quick -> Option.is_some p.defense_raw
    | Stored_modifier | Unknown -> false)
  |> List.iter ~f:row;
  [%expect
    {|
    Servant Daemon                     Ordinary     T10   def   15 -> 15   (qui)  arm 2        pain 3     acc 13 1d8
    Servant Daemon (Variable Armor)    Ordinary     T10   def   15 -> 15   (qui)  arm 1d4      pain 3     acc 13 1d8
    Kvarek                             Ordinary     T11   def   11 -> 13   (qui)  arm 1d8      pain 6     acc 15 1d8
    Fullangra                          Ordinary     T15   def   10 -> 10   (qui)  arm 0        pain 8     acc 5 1d8
    Niha                               Ordinary     T10   def   13 -> 11   (qui)  arm 1d4      pain 3     acc 10 1d8 |}]
;;

let%expect_test "one preset in full, so the record shape is pinned too" =
  print_s
    [%sexp
      (Option.value_exn
         (Symbaroum.Monster_presets.find (Symbaroum.Monster_type.of_string "Spring Elf"))
       : Symbaroum.Monster_preset.t)];
  [%expect
    {|
    ((name       "Spring Elf")
     (category   Elf)
     (resistance Weak)
     (toughness ((
       (current 10)
       (max     10))))
     (defense     (13))
     (defense_raw (-3))
     (defense_reading Stored_modifier)
     (armor ((text 0) (reduction (Unarmored))))
     (pain_threshold (At_least 3))
     (attributes (
       (Accurate   (10))
       (Cunning    (10))
       (Discreet   (15))
       (Persuasive (9))
       (Quick      (13))
       (Resolute   (7))
       (Strong     (5))
       (Vigilant   (11))))
     (attack ((
       (accurate 10)
       (damage (
         (count    1)
         (sides    6)
         (modifier 0)))
       (source (Estimated_from_resistance Weak)))))
     (caveats ((Damage_die_estimated Weak)))) |}]
;;

let%expect_test "golden dump: all 86 presets" =
  List.iter Symbaroum.Monster_presets.all ~f:row;
  [%expect
    {|
    Spring Elf                         Weak         T10   def   -3 -> 13   (mod)  arm 0        pain 3     acc 10 1d6
    Early Summer Elf                   Ordinary     T10   def   -3 -> 13   (mod)  arm 2        pain 4     acc 10 1d8
    Late Summer Elf                    Challenging  T10   def    0 -> 10   (mod)  arm 4        pain 4     acc 15 1d10
    Autumn Elf                         Strong       T10   def    5 -> 5    (mod)  arm 2        pain 4     acc 9 1d12
    Rage Troll (Famished)              Ordinary     T15   def    7 -> 3    (mod)  arm 4        pain 8     acc 13 1d8
    Rage Troll (Group-living)          Challenging  T15   def    7 -> 3    (mod)  arm 4        pain 8     acc 13 1d10
    Liege Troll                        Strong       T18   def    4 -> 6    (mod)  arm 7        pain 9     acc 13 1d12
    Arch Troll                         Mighty       T18   def    7 -> 3    (mod)  arm 10       pain 9     acc 11 1d12+1
    Cult Follower                      Weak         T10   def    1 -> 9    (mod)  arm 2        pain 5     acc 10 1d6
    Cult Leader                        Ordinary     T10   def    5 -> 5    (mod)  arm 2        pain 4     acc 9 1d8
    Queen's Ranger                     Ordinary     T10   def   -4 -> 14   (mod)  arm 2        pain 5     acc 11 1d8
    Ranger Captain                     Challenging  T10   def   -4 -> 14   (mod)  arm 3        pain 5     acc 11 1d10
    Robber Chief                       Ordinary     T10   def    0 -> 10   (mod)  arm 3        pain 5     acc 5 1d8
    Self-taught Witchhunter            Weak         T11   def    3 -> 7    (mod)  arm 3        pain 6     acc 10 1d6
    Black Cloak                        Ordinary     T11   def    3 -> 7    (mod)  arm 3        pain 6     acc 10 1d8
    Village Warrior                    Ordinary     T11   def   -3 -> 13   (mod)  arm 2        pain 6     acc 15 1d8
    Guard Warrior                      Challenging  T15   def   -3 -> 13   (mod)  arm 4        pain 8     acc 5 1d10
    Robber                             Weak         T11   def    4 -> 6    (mod)  arm 3        pain 6     acc 10 1d6
    Fortune-hunter                     Weak         T15   def    1 -> 9    (mod)  arm 2        pain 8     acc 11 1d6
    Plunderer                          Ordinary     T15   def    1 -> 9    (mod)  arm 4        pain 8     acc 5 1d8
    Etterherd                          Ordinary     T10   def   -3 -> 13   (mod)  arm 0        pain 3     acc 15 1d8
    Tricklesting                       Ordinary     T10   def   -5 -> 15   (mod)  arm 0        pain 5     acc 13 1d8
    Baiagorn                           Ordinary     T15   def    7 -> 3    (mod)  arm 4        pain 8     acc 10 1d8
    Mare Cat                           Ordinary     T10   def   -3 -> 13   (mod)  arm 0        pain 4     acc 11 1d8
    Aboar                              Challenging  T15   def    1 -> 9    (mod)  arm 7        pain 8     acc 10 1d10
    Kanaran                            Challenging  T10   def   -4 -> 14   (mod)  arm 4        pain 5     acc 5 1d10
    Lindworm                           Strong       T13   def    4 -> 6    (mod)  arm 8        pain 7     acc 7 1d12
    Sakofal the Slaughterer            Legendary    T36   def    9 -> 1    (mod)  arm 8        pain 9     acc 7 1d12+2
    Violing                            Ordinary     T10   def   -5 -> 15   (mod)  arm 0        pain 5     acc 13 1d8
    Dragon Fly                         Challenging  T11   def   -3 -> 13   (mod)  arm 0        pain 6     acc 15 1d10
    Blight Born Elk                    Challenging  T15   def    0 -> 10   (mod)  arm 3        pain 8     acc 11 1d10
    Blight Born Human                  Ordinary     T11   def    9 -> 1    (mod)  arm 4        pain 6     acc 15 1d8
    Blight Born Aboar                  Strong       T15   def    1 -> 9    (mod)  arm 8        pain 8     acc 7 1d12
    Primal Blight Beast                Mighty       T18   def    3 -> 7    (mod)  arm 10       pain 9     acc 13 1d12+1
    Dragoul                            Ordinary     T15   def    0 -> 10   (mod)  arm 2        pain never acc 9 1d8
    Uhux                               Legendary    T18   def    7 -> 3    (mod)  arm 10       pain never acc 11 1d12+2
    Frost Light                        Weak         T10   def   -3 -> 13   (mod)  arm 0        pain never acc 10 1d6
    Necromage                          Challenging  T10   def   -3 -> 13   (mod)  arm 0        pain never acc 10 1d10
    Cryptwalker                        Strong       T15   def   -3 -> 13   (mod)  arm 0        pain never acc 5 1d12
    Serala-Han Urel                    Legendary    T23   def   -1 -> 11   (mod)  arm 5        pain never acc 10 1d12+2
    Baumelo's Henchmen                 Weak         T15   def    2 -> 8    (mod)  arm 3        pain 8     acc 13 1d6
    Gabba Bigpaw                       Ordinary     T10   def    1 -> 9    (mod)  arm 4        pain 5     acc 10 1d8
    Bodyguard (Goblin)                 Weak         T15   def   -4 -> 14   (mod)  arm 3        pain 8     acc 10 1d6
    Generic Urrbukk                    Weak         T10   def    0 -> 10   (mod)  arm 0        pain 4     acc 9 1d6
    Goblin Warrior                     Weak         T10   def   -1 -> 11   (mod)  arm 4        pain 5     acc 11 1d6
    Xanathâ                           Strong       T10   def   -3 -> 13   (mod)  arm 4        pain 5     acc 10 1d12
    Mal-Rogan/Tanfalls                 Challenging  T17   def   -1 -> 11   (mod)  arm 5        pain never acc 7 1d10
    The Creeping Darkness              Strong       T13   def    1 -> 9    (mod)  arm 0        pain never acc 10 1d12
    Fangafa                            Mighty       T16   def    5 -> 5    (mod)  arm 4        pain 8     acc 7 1d12+1
    Glowing Guards                     Weak         T11   def    3 -> 7    (mod)  arm 4        pain 6     acc 13 1d6
    Brand                              Challenging  T15   def    1 -> 9    (mod)  arm 4        pain 8     acc 13 1d10
    Belago                             Ordinary     T10   def    3 -> 7    (mod)  arm 2        pain 5     acc 10 1d8
    Enlightened Cultist                Ordinary     T10   def    0 -> 10   (mod)  arm 2        pain 5     acc 5 1d8
    Algaya                             Strong       T10   def    1 -> 9    (mod)  arm 2        pain 4     acc 10 1d12
    Experienced Black Cloak            Challenging  T10   def   -4 -> 14   (mod)  arm 2        pain 4     acc 10 1d10
    Competent Black Cloak              Strong       T15   def   -4 -> 14   (mod)  arm 4        pain 8     acc 5 1d12
    Emelia                             Strong       T15   def   -1 -> 11   (mod)  arm 5        pain 8     acc 10 1d12
    Aldoro                             Strong       T10   def    3 -> 7    (mod)  arm 2        pain 3     acc 13 1d12
    Enforcer                           Strong       T15   def   -3 -> 13   (mod)  arm 3        pain 8     acc 10 1d12
    Ervano Vearra                      Mighty       T18   def   -5 -> 15   (mod)  arm 6        pain 9     acc 10 1d12+1
    Fire Spirit                        Challenging  T11   def   -3 -> 13   (mod)  arm 0        pain 6     acc 15 1d10
    Servant Daemon                     Ordinary     T10   def   15 -> 15   (qui)  arm 2        pain 3     acc 13 1d8
    Servant Daemon (Variable Armor)    Ordinary     T10   def   15 -> 15   (qui)  arm 1d4      pain 3     acc 13 1d8
    Vindictive Daemon                  Challenging  T10   def   -1 -> 11   (mod)  arm 3        pain 5     acc 15 1d10
    Vindictive Daemon (Variant)        Challenging  T--   def   -- -> 11   (qui)  arm 0        pain never acc 15 1d10
    Knowledgeable Daemon               Challenging  T15   def    0 -> 10   (mod)  arm 3        pain 8     acc 5 1d10
    Knowledgeable Daemon (Variant)     Challenging  T10   def   -3 -> 13   (mod)  arm 0        pain 3     acc 7 1d10
    Blight Born Fairy                  Weak         T10   def   -3 -> 13   (mod)  arm 0        pain 3     acc 10 1d6
    Rune Guardian                      Challenging  T15   def    6 -> 4    (mod)  arm 4        pain 8     acc 5 1d10
    Baumelo (Odako)                    Ordinary     T15   def    3 -> 7    (mod)  arm 3        pain 8     acc 7 1d8
    Kagliostro                         Strong       T10   def   -1 -> 11   (mod)  arm 5        pain 4     acc 10 1d12
    Warrior Monk                       Challenging  T20   def    0 -> 10   (mod)  arm 3        pain 8     acc 13 1d10
    Lestra                             Ordinary     T10   def    1 -> 9    (mod)  arm 2        pain 4     acc 5 1d8
    Kvarek                             Ordinary     T11   def   11 -> 13   (qui)  arm 1d8      pain 6     acc 15 1d8
    Ansel                              Ordinary     T--   def   -- -> 7    (qui)  arm 0        pain never acc 13 1d8
    Karla                              Ordinary     T--   def   -- -> 13   (qui)  arm 0        pain never acc 5 1d8
    Argasto                            Ordinary     T--   def   -- -> 10   (qui)  arm 0        pain never acc 10 1d8
    Fullangra                          Ordinary     T15   def   10 -> 10   (qui)  arm 0        pain 8     acc 5 1d8
    Niha                               Ordinary     T10   def   13 -> 11   (qui)  arm 1d4      pain 3     acc 10 1d8
    Godrai                             Ordinary     T--   def   -- -> 11   (qui)  arm 0        pain never acc 13 1d8
    Gylta                              Strong       T15   def   -3 -> 13   (mod)  arm 10       pain 8     acc 7 1d12
    Jakaar (Battle-Trained)            Ordinary     T15   def   -3 -> 13   (mod)  arm 2        pain 8     acc 11 1d8
    Jakaar                             Weak         T10   def   -5 -> 15   (mod)  arm 2        pain 5     acc 13 1d6
    Hunger Wolf                        Weak         T--   def   -- -> 15   (qui)  arm 0        pain never acc 10 1d6
    Mal-Rogan (Promised Land)          Challenging  T11   def   -3 -> 13   (mod)  arm 0        pain 6     acc 15 1d10
    Thorn Beasty                       Ordinary     T--   def   -- -> 15   (qui)  arm 0        pain never acc 13 1d8 |}]
;;

let%expect_test "categories, as the add-combatant dialog groups them" =
  List.iter Symbaroum.Monster_presets.by_category ~f:(fun (category, presets) ->
    printf
      "%-26s %d\n"
      (Symbaroum.Monster_preset.Category.to_string category)
      (List.length presets));
  [%expect
    {|
    Abomination                11
    Beast                      7
    Changeling                 1
    Creeper                    1
    Dwarf                      1
    Elf                        5
    Goblin                     4
    Human                      27
    Human/Changeling/Goblin    1
    Human/Goblin               1
    Mystic Being               1
    Ogre                       1
    Phenomenon                 4
    Reptile                    3
    Spider                     3
    Spirit                     5
    Troll                      4
    Undead                     4
    Winged Creature            2 |}]
;;
