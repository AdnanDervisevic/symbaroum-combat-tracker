open! Core

type t =
  { name : Name.t
  ; order : int
  ; initiative : int
  ; toughness : int
  ; defense : Defense.t
  ; flanked : bool
  ; prone : bool
  ; pain_threshold : Pain_threshold.t
  ; accurate : Attribute_value.t
  ; weapon : Pmf.t
  ; armor : Pmf.t
  ; caveats : Caveat.t list
  }
[@@deriving compare, equal, sexp_of]

let assumed_accurate = Attribute_value.of_int_exn 10
let assumed_weapon = Attack_profile.damage_prior Ordinary

let of_combatant (c : Combatant.t) ~order =
  match Combatant.is_down c with
  | true -> None
  | false ->
    let caveats = ref [] in
    let note caveat = caveats := caveat :: !caveats in
    let accurate, weapon =
      match c.attack with
      | Some attack ->
        (match attack.source with
         | From_data -> ()
         | Estimated_from_resistance resistance ->
           note (Caveat.Damage_die_estimated resistance));
        attack.accurate, Pmf.of_dice attack.damage
      | None ->
        (* No weapon recorded, which is every player character in the shipped
           roster. Accurate can still come off the character sheet if it is
           there; the die cannot come from anywhere. *)
        let accurate =
          match Attributes.find c.attributes Accurate with
          | Some accurate -> accurate
          | None -> assumed_accurate
        in
        note Caveat.No_attack_profile;
        accurate, Pmf.of_dice assumed_weapon
    in
    let armor =
      match c.armor.reduction with
      | Some reduction -> Pmf.of_reduction reduction
      | None ->
        note (Caveat.Armor_unparsed c.armor.text);
        Pmf.of_reduction Unarmored
    in
    Some
      { name = c.name
      ; order
      ; initiative = Initiative.to_int c.initiative
      ; toughness = c.toughness.current
      ; defense = c.defense
      ; flanked = c.flanked
      ; prone = c.prone
      ; pain_threshold = c.pain_threshold
      ; accurate
      ; weapon
      ; armor
      ; caveats = List.rev !caveats
      }
;;

let damage_against t ~defender = Pmf.sub_clamped t.weapon defender.armor

let hit_chance t ~defender ~defender_prone =
  Hit_chance.of_matchup
    ~attacker_accurate:t.accurate
    ~defender_defense:defender.defense
    ~defender_prone
    ~defender_flanked:defender.flanked
;;
