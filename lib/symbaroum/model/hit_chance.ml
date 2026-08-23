open! Core

let prone_bonus = 2
let flanked_bonus = 2
let min_target = 1
let max_target = 19
let faces = 20

let target ~attacker_accurate ~defender_defense ~defender_prone ~defender_flanked =
  let situation =
    (if defender_prone then prone_bonus else 0)
    + if defender_flanked then flanked_bonus else 0
  in
  Int.clamp_exn
    (Attribute_value.to_int attacker_accurate
     + Defense.to_modifier defender_defense
     + situation)
    ~min:min_target
    ~max:max_target
;;

let of_matchup ~attacker_accurate ~defender_defense ~defender_prone ~defender_flanked =
  Float.of_int
    (target ~attacker_accurate ~defender_defense ~defender_prone ~defender_flanked)
  /. Float.of_int faces
;;
