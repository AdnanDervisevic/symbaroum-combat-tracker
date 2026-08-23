(* GENERATED FILE -- DO NOT EDIT BY HAND.

   Transcribed from [src/data/defaultMonsters.ts] by
   [scripts/gen_monster_presets.py]. Regenerate with:

   {v
     python3 scripts/gen_monster_presets.py
     ./scripts/dune.sh build @fmt --auto-promote
   v}

   Deliberately uninterpreted: every field here is the wire type, so this
   file can be diffed against the TypeScript line by line. The Defense
   reconciliation, the armour parse and the damage-die estimate all happen
   in [Monster_preset.of_raw]. *)

let raw : Monster_preset.Raw.t list =
  [ { name = "Spring Elf"
    ; category = "Elf"
    ; resistance = "Weak"
    ; toughness = Some 10
    ; defense = Some (-3)
    ; armor = Some "0"
    ; pain_threshold = Some 3
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 10
        ; "dis", Some 15
        ; "per", Some 9
        ; "qui", Some 13
        ; "res", Some 7
        ; "str", Some 5
        ; "vig", Some 11
        ]
    }
  ; { name = "Early Summer Elf"
    ; category = "Elf"
    ; resistance = "Ordinary"
    ; toughness = Some 10
    ; defense = Some (-3)
    ; armor = Some "2"
    ; pain_threshold = Some 4
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 10
        ; "dis", Some 11
        ; "per", Some 5
        ; "qui", Some 13
        ; "res", Some 9
        ; "str", Some 7
        ; "vig", Some 15
        ]
    }
  ; { name = "Late Summer Elf"
    ; category = "Elf"
    ; resistance = "Challenging"
    ; toughness = Some 10
    ; defense = Some 0
    ; armor = Some "4"
    ; pain_threshold = Some 4
    ; attributes =
        [ "acc", Some 15
        ; "cun", Some 10
        ; "dis", Some 11
        ; "per", Some 9
        ; "qui", Some 10
        ; "res", Some 13
        ; "str", Some 7
        ; "vig", Some 5
        ]
    }
  ; { name = "Autumn Elf"
    ; category = "Elf"
    ; resistance = "Strong"
    ; toughness = Some 10
    ; defense = Some 5
    ; armor = Some "2"
    ; pain_threshold = Some 4
    ; attributes =
        [ "acc", Some 9
        ; "cun", Some 13
        ; "dis", Some 10
        ; "per", Some 11
        ; "qui", Some 5
        ; "res", Some 15
        ; "str", Some 7
        ; "vig", Some 10
        ]
    }
  ; { name = "Rage Troll (Famished)"
    ; category = "Troll"
    ; resistance = "Ordinary"
    ; toughness = Some 15
    ; defense = Some 7
    ; armor = Some "4"
    ; pain_threshold = Some 8
    ; attributes =
        [ "acc", Some 13
        ; "cun", Some 10
        ; "dis", Some 5
        ; "per", Some 7
        ; "qui", Some 11
        ; "res", Some 10
        ; "str", Some 15
        ; "vig", Some 9
        ]
    }
  ; { name = "Rage Troll (Group-living)"
    ; category = "Troll"
    ; resistance = "Challenging"
    ; toughness = Some 15
    ; defense = Some 7
    ; armor = Some "4"
    ; pain_threshold = Some 8
    ; attributes =
        [ "acc", Some 13
        ; "cun", Some 10
        ; "dis", Some 5
        ; "per", Some 7
        ; "qui", Some 10
        ; "res", Some 11
        ; "str", Some 15
        ; "vig", Some 9
        ]
    }
  ; { name = "Liege Troll"
    ; category = "Troll"
    ; resistance = "Strong"
    ; toughness = Some 18
    ; defense = Some 4
    ; armor = Some "7"
    ; pain_threshold = Some 9
    ; attributes =
        [ "acc", Some 13
        ; "cun", Some 10
        ; "dis", Some 5
        ; "per", Some 11
        ; "qui", Some 9
        ; "res", Some 10
        ; "str", Some 18
        ; "vig", Some 7
        ]
    }
  ; { name = "Arch Troll"
    ; category = "Troll"
    ; resistance = "Mighty"
    ; toughness = Some 18
    ; defense = Some 7
    ; armor = Some "10"
    ; pain_threshold = Some 9
    ; attributes =
        [ "acc", Some 11
        ; "cun", Some 10
        ; "dis", Some 5
        ; "per", Some 9
        ; "qui", Some 7
        ; "res", Some 16
        ; "str", Some 18
        ; "vig", Some 10
        ]
    }
  ; { name = "Cult Follower"
    ; category = "Human"
    ; resistance = "Weak"
    ; toughness = Some 10
    ; defense = Some 1
    ; armor = Some "2"
    ; pain_threshold = Some 5
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 7
        ; "dis", Some 15
        ; "per", Some 10
        ; "qui", Some 11
        ; "res", Some 5
        ; "str", Some 9
        ; "vig", Some 13
        ]
    }
  ; { name = "Cult Leader"
    ; category = "Human"
    ; resistance = "Ordinary"
    ; toughness = Some 10
    ; defense = Some 5
    ; armor = Some "2"
    ; pain_threshold = Some 4
    ; attributes =
        [ "acc", Some 9
        ; "cun", Some 13
        ; "dis", Some 11
        ; "per", Some 15
        ; "qui", Some 5
        ; "res", Some 10
        ; "str", Some 7
        ; "vig", Some 10
        ]
    }
  ; { name = "Queen's Ranger"
    ; category = "Human"
    ; resistance = "Ordinary"
    ; toughness = Some 10
    ; defense = Some (-4)
    ; armor = Some "2"
    ; pain_threshold = Some 5
    ; attributes =
        [ "acc", Some 11
        ; "cun", Some 13
        ; "dis", Some 10
        ; "per", Some 5
        ; "qui", Some 7
        ; "res", Some 9
        ; "str", Some 10
        ; "vig", Some 15
        ]
    }
  ; { name = "Ranger Captain"
    ; category = "Human"
    ; resistance = "Challenging"
    ; toughness = Some 10
    ; defense = Some (-4)
    ; armor = Some "3"
    ; pain_threshold = Some 5
    ; attributes =
        [ "acc", Some 11
        ; "cun", Some 13
        ; "dis", Some 10
        ; "per", Some 5
        ; "qui", Some 7
        ; "res", Some 9
        ; "str", Some 10
        ; "vig", Some 15
        ]
    }
  ; { name = "Robber Chief"
    ; category = "Human"
    ; resistance = "Ordinary"
    ; toughness = Some 10
    ; defense = Some 0
    ; armor = Some "3"
    ; pain_threshold = Some 5
    ; attributes =
        [ "acc", Some 5
        ; "cun", Some 7
        ; "dis", Some 9
        ; "per", Some 15
        ; "qui", Some 13
        ; "res", Some 10
        ; "str", Some 10
        ; "vig", Some 11
        ]
    }
  ; { name = "Self-taught Witchhunter"
    ; category = "Human"
    ; resistance = "Weak"
    ; toughness = Some 11
    ; defense = Some 3
    ; armor = Some "3"
    ; pain_threshold = Some 6
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 10
        ; "dis", Some 5
        ; "per", Some 7
        ; "qui", Some 9
        ; "res", Some 15
        ; "str", Some 11
        ; "vig", Some 13
        ]
    }
  ; { name = "Black Cloak"
    ; category = "Human"
    ; resistance = "Ordinary"
    ; toughness = Some 11
    ; defense = Some 3
    ; armor = Some "3"
    ; pain_threshold = Some 6
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 10
        ; "dis", Some 5
        ; "per", Some 7
        ; "qui", Some 9
        ; "res", Some 15
        ; "str", Some 11
        ; "vig", Some 13
        ]
    }
  ; { name = "Village Warrior"
    ; category = "Human"
    ; resistance = "Ordinary"
    ; toughness = Some 11
    ; defense = Some (-3)
    ; armor = Some "2"
    ; pain_threshold = Some 6
    ; attributes =
        [ "acc", Some 15
        ; "cun", Some 5
        ; "dis", Some 10
        ; "per", Some 7
        ; "qui", Some 13
        ; "res", Some 9
        ; "str", Some 11
        ; "vig", Some 10
        ]
    }
  ; { name = "Guard Warrior"
    ; category = "Human"
    ; resistance = "Challenging"
    ; toughness = Some 15
    ; defense = Some (-3)
    ; armor = Some "4"
    ; pain_threshold = Some 8
    ; attributes =
        [ "acc", Some 5
        ; "cun", Some 10
        ; "dis", Some 10
        ; "per", Some 7
        ; "qui", Some 13
        ; "res", Some 9
        ; "str", Some 15
        ; "vig", Some 11
        ]
    }
  ; { name = "Robber"
    ; category = "Human/Goblin"
    ; resistance = "Weak"
    ; toughness = Some 11
    ; defense = Some 4
    ; armor = Some "3"
    ; pain_threshold = Some 6
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 5
        ; "dis", Some 13
        ; "per", Some 9
        ; "qui", Some 10
        ; "res", Some 7
        ; "str", Some 11
        ; "vig", Some 15
        ]
    }
  ; { name = "Fortune-hunter"
    ; category = "Human/Changeling/Goblin"
    ; resistance = "Weak"
    ; toughness = Some 15
    ; defense = Some 1
    ; armor = Some "2"
    ; pain_threshold = Some 8
    ; attributes =
        [ "acc", Some 11
        ; "cun", Some 10
        ; "dis", Some 9
        ; "per", Some 5
        ; "qui", Some 10
        ; "res", Some 7
        ; "str", Some 15
        ; "vig", Some 13
        ]
    }
  ; { name = "Plunderer"
    ; category = "Ogre"
    ; resistance = "Ordinary"
    ; toughness = Some 15
    ; defense = Some 1
    ; armor = Some "4"
    ; pain_threshold = Some 8
    ; attributes =
        [ "acc", Some 5
        ; "cun", Some 10
        ; "dis", Some 9
        ; "per", Some 10
        ; "qui", Some 13
        ; "res", Some 11
        ; "str", Some 15
        ; "vig", Some 7
        ]
    }
  ; { name = "Etterherd"
    ; category = "Spider"
    ; resistance = "Ordinary"
    ; toughness = Some 10
    ; defense = Some (-3)
    ; armor = Some "0"
    ; pain_threshold = Some 3
    ; attributes =
        [ "acc", Some 15
        ; "cun", Some 10
        ; "dis", Some 11
        ; "per", Some 7
        ; "qui", Some 13
        ; "res", Some 9
        ; "str", Some 5
        ; "vig", Some 10
        ]
    }
  ; { name = "Tricklesting"
    ; category = "Spider"
    ; resistance = "Ordinary"
    ; toughness = Some 10
    ; defense = Some (-5)
    ; armor = Some "0"
    ; pain_threshold = Some 5
    ; attributes =
        [ "acc", Some 13
        ; "cun", Some 10
        ; "dis", Some 11
        ; "per", Some 5
        ; "qui", Some 15
        ; "res", Some 7
        ; "str", Some 9
        ; "vig", Some 10
        ]
    }
  ; { name = "Baiagorn"
    ; category = "Beast"
    ; resistance = "Ordinary"
    ; toughness = Some 15
    ; defense = Some 7
    ; armor = Some "4"
    ; pain_threshold = Some 8
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 10
        ; "dis", Some 9
        ; "per", Some 5
        ; "qui", Some 7
        ; "res", Some 13
        ; "str", Some 15
        ; "vig", Some 11
        ]
    }
  ; { name = "Mare Cat"
    ; category = "Beast"
    ; resistance = "Ordinary"
    ; toughness = Some 10
    ; defense = Some (-3)
    ; armor = Some "0"
    ; pain_threshold = Some 4
    ; attributes =
        [ "acc", Some 11
        ; "cun", Some 9
        ; "dis", Some 15
        ; "per", Some 5
        ; "qui", Some 13
        ; "res", Some 10
        ; "str", Some 7
        ; "vig", Some 10
        ]
    }
  ; { name = "Aboar"
    ; category = "Beast"
    ; resistance = "Challenging"
    ; toughness = Some 15
    ; defense = Some 1
    ; armor = Some "7"
    ; pain_threshold = Some 8
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 10
        ; "dis", Some 7
        ; "per", Some 5
        ; "qui", Some 13
        ; "res", Some 11
        ; "str", Some 15
        ; "vig", Some 9
        ]
    }
  ; { name = "Kanaran"
    ; category = "Reptile"
    ; resistance = "Challenging"
    ; toughness = Some 10
    ; defense = Some (-4)
    ; armor = Some "4"
    ; pain_threshold = Some 5
    ; attributes =
        [ "acc", Some 5
        ; "cun", Some 16
        ; "dis", Some 11
        ; "per", Some 7
        ; "qui", Some 14
        ; "res", Some 9
        ; "str", Some 10
        ; "vig", Some 10
        ]
    }
  ; { name = "Lindworm"
    ; category = "Reptile"
    ; resistance = "Strong"
    ; toughness = Some 13
    ; defense = Some 4
    ; armor = Some "8"
    ; pain_threshold = Some 7
    ; attributes =
        [ "acc", Some 7
        ; "cun", Some 9
        ; "dis", Some 5
        ; "per", Some 11
        ; "qui", Some 10
        ; "res", Some 15
        ; "str", Some 13
        ; "vig", Some 10
        ]
    }
  ; { name = "Sakofal the Slaughterer"
    ; category = "Reptile"
    ; resistance = "Legendary"
    ; toughness = Some 36
    ; defense = Some 9
    ; armor = Some "8"
    ; pain_threshold = Some 9
    ; attributes =
        [ "acc", Some 7
        ; "cun", Some 9
        ; "dis", Some 5
        ; "per", Some 11
        ; "qui", Some 10
        ; "res", Some 17
        ; "str", Some 18
        ; "vig", Some 10
        ]
    }
  ; { name = "Violing"
    ; category = "Winged Creature"
    ; resistance = "Ordinary"
    ; toughness = Some 10
    ; defense = Some (-5)
    ; armor = Some "0"
    ; pain_threshold = Some 5
    ; attributes =
        [ "acc", Some 13
        ; "cun", Some 10
        ; "dis", Some 5
        ; "per", Some 7
        ; "qui", Some 15
        ; "res", Some 10
        ; "str", Some 9
        ; "vig", Some 11
        ]
    }
  ; { name = "Dragon Fly"
    ; category = "Winged Creature"
    ; resistance = "Challenging"
    ; toughness = Some 11
    ; defense = Some (-3)
    ; armor = Some "0"
    ; pain_threshold = Some 6
    ; attributes =
        [ "acc", Some 15
        ; "cun", Some 5
        ; "dis", Some 7
        ; "per", Some 10
        ; "qui", Some 13
        ; "res", Some 10
        ; "str", Some 11
        ; "vig", Some 9
        ]
    }
  ; { name = "Blight Born Elk"
    ; category = "Abomination"
    ; resistance = "Challenging"
    ; toughness = Some 15
    ; defense = Some 0
    ; armor = Some "3"
    ; pain_threshold = Some 8
    ; attributes =
        [ "acc", Some 11
        ; "cun", Some 7
        ; "dis", Some 10
        ; "per", Some 5
        ; "qui", Some 13
        ; "res", Some 9
        ; "str", Some 15
        ; "vig", Some 10
        ]
    }
  ; { name = "Blight Born Human"
    ; category = "Abomination"
    ; resistance = "Ordinary"
    ; toughness = Some 11
    ; defense = Some 9
    ; armor = Some "4"
    ; pain_threshold = Some 6
    ; attributes =
        [ "acc", Some 15
        ; "cun", Some 9
        ; "dis", Some 10
        ; "per", Some 5
        ; "qui", Some 7
        ; "res", Some 13
        ; "str", Some 11
        ; "vig", Some 10
        ]
    }
  ; { name = "Blight Born Aboar"
    ; category = "Abomination"
    ; resistance = "Strong"
    ; toughness = Some 15
    ; defense = Some 1
    ; armor = Some "8"
    ; pain_threshold = Some 8
    ; attributes =
        [ "acc", Some 7
        ; "cun", Some 10
        ; "dis", Some 7
        ; "per", Some 5
        ; "qui", Some 13
        ; "res", Some 11
        ; "str", Some 15
        ; "vig", Some 9
        ]
    }
  ; { name = "Primal Blight Beast"
    ; category = "Abomination"
    ; resistance = "Mighty"
    ; toughness = Some 18
    ; defense = Some 3
    ; armor = Some "10"
    ; pain_threshold = Some 9
    ; attributes =
        [ "acc", Some 13
        ; "cun", Some 9
        ; "dis", Some 5
        ; "per", Some 7
        ; "qui", Some 11
        ; "res", Some 10
        ; "str", Some 18
        ; "vig", Some 10
        ]
    }
  ; { name = "Dragoul"
    ; category = "Undead"
    ; resistance = "Ordinary"
    ; toughness = Some 15
    ; defense = Some 0
    ; armor = Some "2"
    ; pain_threshold = None
    ; attributes =
        [ "acc", Some 9
        ; "cun", Some 7
        ; "dis", Some 10
        ; "per", Some 5
        ; "qui", Some 10
        ; "res", Some 13
        ; "str", Some 15
        ; "vig", Some 11
        ]
    }
  ; { name = "Uhux"
    ; category = "Undead"
    ; resistance = "Legendary"
    ; toughness = Some 18
    ; defense = Some 7
    ; armor = Some "10"
    ; pain_threshold = None
    ; attributes =
        [ "acc", Some 11
        ; "cun", Some 10
        ; "dis", Some 5
        ; "per", Some 9
        ; "qui", Some 7
        ; "res", Some 16
        ; "str", Some 18
        ; "vig", Some 10
        ]
    }
  ; { name = "Frost Light"
    ; category = "Spirit"
    ; resistance = "Weak"
    ; toughness = Some 10
    ; defense = Some (-3)
    ; armor = Some "0"
    ; pain_threshold = None
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 9
        ; "dis", Some 11
        ; "per", Some 5
        ; "qui", Some 13
        ; "res", Some 15
        ; "str", Some 7
        ; "vig", Some 10
        ]
    }
  ; { name = "Necromage"
    ; category = "Spirit"
    ; resistance = "Challenging"
    ; toughness = Some 10
    ; defense = Some (-3)
    ; armor = Some "0"
    ; pain_threshold = None
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 9
        ; "dis", Some 11
        ; "per", Some 5
        ; "qui", Some 13
        ; "res", Some 15
        ; "str", Some 7
        ; "vig", Some 10
        ]
    }
  ; { name = "Cryptwalker"
    ; category = "Spirit"
    ; resistance = "Strong"
    ; toughness = Some 15
    ; defense = Some (-3)
    ; armor = Some "0"
    ; pain_threshold = None
    ; attributes =
        [ "acc", Some 5
        ; "cun", Some 10
        ; "dis", Some 7
        ; "per", Some 10
        ; "qui", Some 11
        ; "res", Some 13
        ; "str", Some 15
        ; "vig", Some 9
        ]
    }
  ; { name = "Serala-Han Urel"
    ; category = "Spirit"
    ; resistance = "Legendary"
    ; toughness = Some 23
    ; defense = Some (-1)
    ; armor = Some "5"
    ; pain_threshold = None
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 9
        ; "dis", Some 7
        ; "per", Some 10
        ; "qui", Some 14
        ; "res", Some 16
        ; "str", Some 18
        ; "vig", Some 5
        ]
    }
  ; { name = "Baumelo's Henchmen"
    ; category = "Human"
    ; resistance = "Weak"
    ; toughness = Some 15
    ; defense = Some 2
    ; armor = Some "3"
    ; pain_threshold = Some 8
    ; attributes =
        [ "acc", Some 13
        ; "cun", Some 7
        ; "dis", Some 5
        ; "per", Some 9
        ; "qui", Some 10
        ; "res", Some 11
        ; "str", Some 15
        ; "vig", Some 10
        ]
    }
  ; { name = "Gabba Bigpaw"
    ; category = "Goblin"
    ; resistance = "Ordinary"
    ; toughness = Some 10
    ; defense = Some 1
    ; armor = Some "4"
    ; pain_threshold = Some 5
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 16
        ; "dis", Some 13
        ; "per", Some 10
        ; "qui", Some 11
        ; "res", Some 7
        ; "str", Some 9
        ; "vig", Some 5
        ]
    }
  ; { name = "Bodyguard (Goblin)"
    ; category = "Goblin"
    ; resistance = "Weak"
    ; toughness = Some 15
    ; defense = Some (-4)
    ; armor = Some "3"
    ; pain_threshold = Some 8
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 9
        ; "dis", Some 11
        ; "per", Some 10
        ; "qui", Some 15
        ; "res", Some 7
        ; "str", Some 13
        ; "vig", Some 5
        ]
    }
  ; { name = "Generic Urrbukk"
    ; category = "Goblin"
    ; resistance = "Weak"
    ; toughness = Some 10
    ; defense = Some 0
    ; armor = Some "0"
    ; pain_threshold = Some 4
    ; attributes =
        [ "acc", Some 9
        ; "cun", Some 11
        ; "dis", Some 15
        ; "per", Some 10
        ; "qui", Some 10
        ; "res", Some 5
        ; "str", Some 7
        ; "vig", Some 13
        ]
    }
  ; { name = "Goblin Warrior"
    ; category = "Goblin"
    ; resistance = "Weak"
    ; toughness = Some 10
    ; defense = Some (-1)
    ; armor = Some "4"
    ; pain_threshold = Some 5
    ; attributes =
        [ "acc", Some 11
        ; "cun", Some 9
        ; "dis", Some 15
        ; "per", Some 5
        ; "qui", Some 13
        ; "res", Some 10
        ; "str", Some 10
        ; "vig", Some 7
        ]
    }
  ; { name = "Xanathâ"
    ; category = "Spider"
    ; resistance = "Strong"
    ; toughness = Some 10
    ; defense = Some (-3)
    ; armor = Some "4"
    ; pain_threshold = Some 5
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 17
        ; "dis", Some 11
        ; "per", Some 5
        ; "qui", Some 13
        ; "res", Some 7
        ; "str", Some 9
        ; "vig", Some 10
        ]
    }
  ; { name = "Mal-Rogan/Tanfalls"
    ; category = "Undead"
    ; resistance = "Challenging"
    ; toughness = Some 17
    ; defense = Some (-1)
    ; armor = Some "5"
    ; pain_threshold = None
    ; attributes =
        [ "acc", Some 7
        ; "cun", Some 5
        ; "dis", Some 9
        ; "per", Some 10
        ; "qui", Some 11
        ; "res", Some 13
        ; "str", Some 17
        ; "vig", Some 10
        ]
    }
  ; { name = "The Creeping Darkness"
    ; category = "Phenomenon"
    ; resistance = "Strong"
    ; toughness = Some 13
    ; defense = Some 1
    ; armor = Some "0"
    ; pain_threshold = None
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 11
        ; "dis", Some 7
        ; "per", Some 5
        ; "qui", Some 9
        ; "res", Some 18
        ; "str", Some 13
        ; "vig", Some 10
        ]
    }
  ; { name = "Fangafa"
    ; category = "Phenomenon"
    ; resistance = "Mighty"
    ; toughness = Some 16
    ; defense = Some 5
    ; armor = Some "4"
    ; pain_threshold = Some 8
    ; attributes =
        [ "acc", Some 7
        ; "cun", Some 10
        ; "dis", Some 10
        ; "per", Some 5
        ; "qui", Some 9
        ; "res", Some 18
        ; "str", Some 16
        ; "vig", Some 11
        ]
    }
  ; { name = "Glowing Guards"
    ; category = "Phenomenon"
    ; resistance = "Weak"
    ; toughness = Some 11
    ; defense = Some 3
    ; armor = Some "4"
    ; pain_threshold = Some 6
    ; attributes =
        [ "acc", Some 13
        ; "cun", Some 7
        ; "dis", Some 9
        ; "per", Some 5
        ; "qui", Some 10
        ; "res", Some 15
        ; "str", Some 11
        ; "vig", Some 10
        ]
    }
  ; { name = "Brand"
    ; category = "Phenomenon"
    ; resistance = "Challenging"
    ; toughness = Some 15
    ; defense = Some 1
    ; armor = Some "4"
    ; pain_threshold = Some 8
    ; attributes =
        [ "acc", Some 13
        ; "cun", Some 7
        ; "dis", Some 9
        ; "per", Some 5
        ; "qui", Some 11
        ; "res", Some 10
        ; "str", Some 15
        ; "vig", Some 10
        ]
    }
  ; { name = "Belago"
    ; category = "Human"
    ; resistance = "Ordinary"
    ; toughness = Some 10
    ; defense = Some 3
    ; armor = Some "2"
    ; pain_threshold = Some 5
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 11
        ; "dis", Some 5
        ; "per", Some 15
        ; "qui", Some 7
        ; "res", Some 13
        ; "str", Some 9
        ; "vig", Some 10
        ]
    }
  ; { name = "Enlightened Cultist"
    ; category = "Human"
    ; resistance = "Ordinary"
    ; toughness = Some 10
    ; defense = Some 0
    ; armor = Some "2"
    ; pain_threshold = Some 5
    ; attributes =
        [ "acc", Some 5
        ; "cun", Some 13
        ; "dis", Some 10
        ; "per", Some 7
        ; "qui", Some 10
        ; "res", Some 11
        ; "str", Some 9
        ; "vig", Some 15
        ]
    }
  ; { name = "Algaya"
    ; category = "Human"
    ; resistance = "Strong"
    ; toughness = Some 10
    ; defense = Some 1
    ; armor = Some "2"
    ; pain_threshold = Some 4
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 11
        ; "dis", Some 5
        ; "per", Some 13
        ; "qui", Some 9
        ; "res", Some 16
        ; "str", Some 7
        ; "vig", Some 10
        ]
    }
  ; { name = "Experienced Black Cloak"
    ; category = "Human"
    ; resistance = "Challenging"
    ; toughness = Some 10
    ; defense = Some (-4)
    ; armor = Some "2"
    ; pain_threshold = Some 4
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 10
        ; "dis", Some 15
        ; "per", Some 11
        ; "qui", Some 13
        ; "res", Some 9
        ; "str", Some 7
        ; "vig", Some 5
        ]
    }
  ; { name = "Competent Black Cloak"
    ; category = "Human"
    ; resistance = "Strong"
    ; toughness = Some 15
    ; defense = Some (-4)
    ; armor = Some "4"
    ; pain_threshold = Some 8
    ; attributes =
        [ "acc", Some 5
        ; "cun", Some 10
        ; "dis", Some 10
        ; "per", Some 15
        ; "qui", Some 13
        ; "res", Some 9
        ; "str", Some 7
        ; "vig", Some 11
        ]
    }
  ; { name = "Emelia"
    ; category = "Human"
    ; resistance = "Strong"
    ; toughness = Some 15
    ; defense = Some (-1)
    ; armor = Some "5"
    ; pain_threshold = Some 8
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 10
        ; "dis", Some 5
        ; "per", Some 9
        ; "qui", Some 11
        ; "res", Some 13
        ; "str", Some 15
        ; "vig", Some 7
        ]
    }
  ; { name = "Aldoro"
    ; category = "Human"
    ; resistance = "Strong"
    ; toughness = Some 10
    ; defense = Some 3
    ; armor = Some "2"
    ; pain_threshold = Some 3
    ; attributes =
        [ "acc", Some 13
        ; "cun", Some 9
        ; "dis", Some 10
        ; "per", Some 11
        ; "qui", Some 7
        ; "res", Some 15
        ; "str", Some 5
        ; "vig", Some 10
        ]
    }
  ; { name = "Enforcer"
    ; category = "Human"
    ; resistance = "Strong"
    ; toughness = Some 15
    ; defense = Some (-3)
    ; armor = Some "3"
    ; pain_threshold = Some 8
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 9
        ; "dis", Some 5
        ; "per", Some 10
        ; "qui", Some 13
        ; "res", Some 11
        ; "str", Some 15
        ; "vig", Some 7
        ]
    }
  ; { name = "Ervano Vearra"
    ; category = "Human"
    ; resistance = "Mighty"
    ; toughness = Some 18
    ; defense = Some (-5)
    ; armor = Some "6"
    ; pain_threshold = Some 9
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 7
        ; "dis", Some 5
        ; "per", Some 11
        ; "qui", Some 15
        ; "res", Some 16
        ; "str", Some 18
        ; "vig", Some 9
        ]
    }
  ; { name = "Fire Spirit"
    ; category = "Spirit"
    ; resistance = "Challenging"
    ; toughness = Some 11
    ; defense = Some (-3)
    ; armor = Some "0"
    ; pain_threshold = Some 6
    ; attributes =
        [ "acc", Some 15
        ; "cun", Some 10
        ; "dis", Some 5
        ; "per", Some 7
        ; "qui", Some 13
        ; "res", Some 9
        ; "str", Some 11
        ; "vig", Some 10
        ]
    }
  ; { name = "Servant Daemon"
    ; category = "Abomination"
    ; resistance = "Ordinary"
    ; toughness = Some 10
    ; defense = Some 15
    ; armor = Some "2"
    ; pain_threshold = Some 3
    ; attributes =
        [ "acc", Some 13
        ; "cun", Some 10
        ; "dis", Some 11
        ; "per", Some 5
        ; "qui", Some 15
        ; "res", Some 9
        ; "str", Some 7
        ; "vig", Some 10
        ]
    }
  ; { name = "Servant Daemon (Variable Armor)"
    ; category = "Abomination"
    ; resistance = "Ordinary"
    ; toughness = Some 10
    ; defense = Some 15
    ; armor = Some "1D4"
    ; pain_threshold = Some 3
    ; attributes =
        [ "acc", Some 13
        ; "cun", Some 10
        ; "dis", Some 11
        ; "per", Some 5
        ; "qui", Some 15
        ; "res", Some 9
        ; "str", Some 7
        ; "vig", Some 10
        ]
    }
  ; { name = "Vindictive Daemon"
    ; category = "Abomination"
    ; resistance = "Challenging"
    ; toughness = Some 10
    ; defense = Some (-1)
    ; armor = Some "3"
    ; pain_threshold = Some 5
    ; attributes =
        [ "acc", Some 15
        ; "cun", Some 10
        ; "dis", Some 13
        ; "per", Some 5
        ; "qui", Some 11
        ; "res", Some 7
        ; "str", Some 9
        ; "vig", Some 10
        ]
    }
  ; { name = "Vindictive Daemon (Variant)"
    ; category = "Abomination"
    ; resistance = "Challenging"
    ; toughness = None
    ; defense = None
    ; armor = None
    ; pain_threshold = None
    ; attributes =
        [ "acc", Some 15
        ; "cun", Some 10
        ; "dis", Some 13
        ; "per", Some 5
        ; "qui", Some 11
        ; "res", Some 7
        ; "str", Some 9
        ; "vig", Some 10
        ]
    }
  ; { name = "Knowledgeable Daemon"
    ; category = "Abomination"
    ; resistance = "Challenging"
    ; toughness = Some 15
    ; defense = Some 0
    ; armor = Some "3"
    ; pain_threshold = Some 8
    ; attributes =
        [ "acc", Some 5
        ; "cun", Some 10
        ; "dis", Some 9
        ; "per", Some 7
        ; "qui", Some 13
        ; "res", Some 10
        ; "str", Some 15
        ; "vig", Some 11
        ]
    }
  ; { name = "Knowledgeable Daemon (Variant)"
    ; category = "Abomination"
    ; resistance = "Challenging"
    ; toughness = Some 10
    ; defense = Some (-3)
    ; armor = None
    ; pain_threshold = Some 3
    ; attributes =
        [ "acc", Some 7
        ; "cun", Some 10
        ; "dis", Some 9
        ; "per", Some 11
        ; "qui", Some 13
        ; "res", Some 15
        ; "str", Some 5
        ; "vig", Some 10
        ]
    }
  ; { name = "Blight Born Fairy"
    ; category = "Abomination"
    ; resistance = "Weak"
    ; toughness = Some 10
    ; defense = Some (-3)
    ; armor = Some "0"
    ; pain_threshold = Some 3
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 10
        ; "dis", Some 15
        ; "per", Some 9
        ; "qui", Some 13
        ; "res", Some 7
        ; "str", Some 5
        ; "vig", Some 11
        ]
    }
  ; { name = "Rune Guardian"
    ; category = "Mystic Being"
    ; resistance = "Challenging"
    ; toughness = Some 15
    ; defense = Some 6
    ; armor = Some "4"
    ; pain_threshold = Some 8
    ; attributes =
        [ "acc", Some 5
        ; "cun", Some 10
        ; "dis", Some 7
        ; "per", Some 9
        ; "qui", Some 10
        ; "res", Some 11
        ; "str", Some 15
        ; "vig", Some 13
        ]
    }
  ; { name = "Baumelo (Odako)"
    ; category = "Human"
    ; resistance = "Ordinary"
    ; toughness = Some 15
    ; defense = Some 3
    ; armor = Some "3"
    ; pain_threshold = Some 8
    ; attributes =
        [ "acc", Some 7
        ; "cun", Some 11
        ; "dis", Some 10
        ; "per", Some 15
        ; "qui", Some 9
        ; "res", Some 13
        ; "str", Some 5
        ; "vig", Some 10
        ]
    }
  ; { name = "Kagliostro"
    ; category = "Human"
    ; resistance = "Strong"
    ; toughness = Some 10
    ; defense = Some (-1)
    ; armor = Some "5"
    ; pain_threshold = Some 4
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 10
        ; "dis", Some 13
        ; "per", Some 15
        ; "qui", Some 11
        ; "res", Some 9
        ; "str", Some 7
        ; "vig", Some 5
        ]
    }
  ; { name = "Warrior Monk"
    ; category = "Human"
    ; resistance = "Challenging"
    ; toughness = Some 20
    ; defense = Some 0
    ; armor = Some "3"
    ; pain_threshold = Some 8
    ; attributes =
        [ "acc", Some 13
        ; "cun", Some 7
        ; "dis", Some 5
        ; "per", Some 9
        ; "qui", Some 10
        ; "res", Some 11
        ; "str", Some 15
        ; "vig", Some 10
        ]
    }
  ; { name = "Lestra"
    ; category = "Human"
    ; resistance = "Ordinary"
    ; toughness = Some 10
    ; defense = Some 1
    ; armor = Some "2"
    ; pain_threshold = Some 4
    ; attributes =
        [ "acc", Some 5
        ; "cun", Some 15
        ; "dis", Some 10
        ; "per", Some 10
        ; "qui", Some 9
        ; "res", Some 13
        ; "str", Some 7
        ; "vig", Some 11
        ]
    }
  ; { name = "Kvarek"
    ; category = "Human"
    ; resistance = "Ordinary"
    ; toughness = Some 11
    ; defense = Some 11
    ; armor = Some "1D8"
    ; pain_threshold = Some 6
    ; attributes =
        [ "acc", Some 15
        ; "cun", Some 9
        ; "dis", Some 7
        ; "per", Some 5
        ; "qui", Some 13
        ; "res", Some 10
        ; "str", Some 11
        ; "vig", Some 10
        ]
    }
  ; { name = "Ansel"
    ; category = "Human"
    ; resistance = "Ordinary"
    ; toughness = None
    ; defense = None
    ; armor = None
    ; pain_threshold = None
    ; attributes =
        [ "acc", Some 13
        ; "cun", Some 10
        ; "dis", Some 5
        ; "per", Some 15
        ; "qui", Some 7
        ; "res", Some 11
        ; "str", Some 9
        ; "vig", Some 10
        ]
    }
  ; { name = "Karla"
    ; category = "Human"
    ; resistance = "Ordinary"
    ; toughness = None
    ; defense = None
    ; armor = None
    ; pain_threshold = None
    ; attributes =
        [ "acc", Some 5
        ; "cun", Some 7
        ; "dis", Some 11
        ; "per", Some 9
        ; "qui", Some 13
        ; "res", Some 10
        ; "str", Some 10
        ; "vig", Some 15
        ]
    }
  ; { name = "Argasto"
    ; category = "Human"
    ; resistance = "Ordinary"
    ; toughness = None
    ; defense = None
    ; armor = None
    ; pain_threshold = None
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 11
        ; "dis", Some 5
        ; "per", Some 15
        ; "qui", Some 10
        ; "res", Some 9
        ; "str", Some 13
        ; "vig", Some 7
        ]
    }
  ; { name = "Fullangra"
    ; category = "Dwarf"
    ; resistance = "Ordinary"
    ; toughness = Some 15
    ; defense = Some 10
    ; armor = None
    ; pain_threshold = Some 8
    ; attributes =
        [ "acc", Some 5
        ; "cun", Some 13
        ; "dis", Some 10
        ; "per", Some 7
        ; "qui", Some 10
        ; "res", Some 9
        ; "str", Some 15
        ; "vig", Some 11
        ]
    }
  ; { name = "Niha"
    ; category = "Changeling"
    ; resistance = "Ordinary"
    ; toughness = Some 10
    ; defense = Some 13
    ; armor = Some "1D4"
    ; pain_threshold = Some 3
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 7
        ; "dis", Some 15
        ; "per", Some 13
        ; "qui", Some 11
        ; "res", Some 9
        ; "str", Some 5
        ; "vig", Some 10
        ]
    }
  ; { name = "Godrai"
    ; category = "Elf"
    ; resistance = "Ordinary"
    ; toughness = None
    ; defense = None
    ; armor = None
    ; pain_threshold = None
    ; attributes =
        [ "acc", Some 13
        ; "cun", Some 7
        ; "dis", Some 5
        ; "per", Some 9
        ; "qui", Some 11
        ; "res", Some 10
        ; "str", Some 15
        ; "vig", Some 10
        ]
    }
  ; { name = "Gylta"
    ; category = "Beast"
    ; resistance = "Strong"
    ; toughness = Some 15
    ; defense = Some (-3)
    ; armor = Some "10"
    ; pain_threshold = Some 8
    ; attributes =
        [ "acc", Some 7
        ; "cun", Some 10
        ; "dis", Some 10
        ; "per", Some 5
        ; "qui", Some 13
        ; "res", Some 11
        ; "str", Some 15
        ; "vig", Some 9
        ]
    }
  ; { name = "Jakaar (Battle-Trained)"
    ; category = "Beast"
    ; resistance = "Ordinary"
    ; toughness = Some 15
    ; defense = Some (-3)
    ; armor = Some "2"
    ; pain_threshold = Some 8
    ; attributes =
        [ "acc", Some 11
        ; "cun", Some 7
        ; "dis", Some 10
        ; "per", Some 5
        ; "qui", Some 13
        ; "res", Some 9
        ; "str", Some 15
        ; "vig", Some 10
        ]
    }
  ; { name = "Jakaar"
    ; category = "Beast"
    ; resistance = "Weak"
    ; toughness = Some 10
    ; defense = Some (-5)
    ; armor = Some "2"
    ; pain_threshold = Some 5
    ; attributes =
        [ "acc", Some 13
        ; "cun", Some 7
        ; "dis", Some 11
        ; "per", Some 5
        ; "qui", Some 15
        ; "res", Some 9
        ; "str", Some 10
        ; "vig", Some 10
        ]
    }
  ; { name = "Hunger Wolf"
    ; category = "Beast"
    ; resistance = "Weak"
    ; toughness = None
    ; defense = None
    ; armor = None
    ; pain_threshold = None
    ; attributes =
        [ "acc", Some 10
        ; "cun", Some 7
        ; "dis", Some 5
        ; "per", Some 9
        ; "qui", Some 15
        ; "res", Some 13
        ; "str", Some 11
        ; "vig", Some 10
        ]
    }
  ; { name = "Mal-Rogan (Promised Land)"
    ; category = "Undead"
    ; resistance = "Challenging"
    ; toughness = Some 11
    ; defense = Some (-3)
    ; armor = None
    ; pain_threshold = Some 6
    ; attributes =
        [ "acc", Some 15
        ; "cun", Some 10
        ; "dis", Some 5
        ; "per", Some 7
        ; "qui", Some 13
        ; "res", Some 9
        ; "str", Some 11
        ; "vig", Some 10
        ]
    }
  ; { name = "Thorn Beasty"
    ; category = "Creeper"
    ; resistance = "Ordinary"
    ; toughness = None
    ; defense = None
    ; armor = None
    ; pain_threshold = None
    ; attributes =
        [ "acc", Some 13
        ; "cun", Some 10
        ; "dis", Some 11
        ; "per", Some 5
        ; "qui", Some 15
        ; "res", Some 9
        ; "str", Some 7
        ; "vig", Some 10
        ]
    }
  ]
;;
