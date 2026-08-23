open! Core

(* A local accumulator for the repairs. [to_domain] is still a function -- the
   ref never escapes it -- and threading a list through fifteen field
   conversions would bury the conversions under the plumbing. *)
module Repairs = struct
  type t = Normalization.t list ref

  let create () : t = ref []
  let add (t : t) n = t := n :: !t
  let add_all (t : t) ns = List.iter ns ~f:(add t)
  let to_list (t : t) = List.rev !t
end

(* Milliseconds cross the wire as a [float]. [Time_ns.t] is [Int63]-backed and so
   is fine everywhere, but a plain [int] is 32 bits under js_of_ocaml and a
   JavaScript timestamp is about 1.7e12 -- so an [int] here would be silently
   wrong in the browser and right in every native test. *)
let ms_to_time ms = Time_ns.of_span_since_epoch (Time_ns.Span.of_ms ms)
let time_to_ms time = Time_ns.Span.to_ms (Time_ns.to_span_since_epoch time)

(* Every bounded scalar arrives the same way: try the honest constructor, and if
   the value is out of range, saturate and say so. *)
let bounded repairs ~field ~of_int ~clamp ~to_int given =
  match (of_int given : _ Or_error.t) with
  | Ok value -> value
  | Error _ ->
    let value = clamp given in
    Repairs.add repairs (Value_clamped { field; given; used = to_int value });
    value
;;

let initiative repairs ~field given =
  bounded
    repairs
    ~field
    ~of_int:Initiative.of_int
    ~clamp:Initiative.of_int_clamped
    ~to_int:Initiative.to_int
    given
;;

(* The label says which reading the number is. By the time it reaches here it is
   always a roll-under target, but a v1 monster row wrote a modifier and
   [Migrate] converted it, so a report naming the bare field could show a number
   the GM cannot find in their file. *)
let defense repairs ~field given =
  bounded
    repairs
    ~field:[%string "%{field} (as a roll-under target)"]
    ~of_int:Defense.of_target
    ~clamp:Defense.of_int_clamped
    ~to_int:Defense.to_int
    given
;;

let toughness repairs ~field (t : Wire_v2.Toughness.t) =
  match Toughness.create ~current:t.current ~max:t.max with
  | Ok value -> value
  | Error _ ->
    let value = Toughness.create_clamped ~current:t.current ~max:t.max in
    Repairs.add repairs (Value_clamped { field; given = t.current; used = value.current });
    value
;;

(* Deliberately not reported, and the round-trip property is what settled it.

   The plan listed [Armor_unparsed] as a normalization. It is not one. A
   normalization is a value this module {i changed}; [Armor.parse] is total and
   keeps the text verbatim, so ["scales"] goes in and ["scales"] comes out and
   nothing was corrected. Reporting it would make an import that changed nothing
   announce "Loaded -- 3 corrections applied", which is a lie, and it made the
   round trip fail its strong form for a file the app had just written itself.

   That the model cannot use ["scales"] is still worth showing a GM -- but it is
   a property of the value, answerable at any time by {!Armor.is_unparsed}, not
   an event that happened during a load. Asking the world is also the version
   that stays true after an edit. *)
let armor text = Armor.parse text

let attributes repairs ~field (a : Wire_v2.Attributes.t) =
  let score key given =
    Option.map given ~f:(fun given ->
      bounded
        repairs
        ~field:[%string "%{field}.%{key}"]
        ~of_int:Attribute_value.of_int
        ~clamp:Attribute_value.of_int_clamped
        ~to_int:Attribute_value.to_int
        given)
  in
  List.fold
    [ Attribute.Accurate, score "acc" a.acc
    ; Cunning, score "cun" a.cun
    ; Discreet, score "dis" a.dis
    ; Persuasive, score "per" a.per
    ; Quick, score "qui" a.qui
    ; Resolute, score "res" a.res
    ; Strong, score "str" a.str
    ; Vigilant, score "vig" a.vig
    ]
    ~init:Attributes.empty
    ~f:(fun acc (attribute, value) -> Attributes.set acc attribute value)
;;

let attack repairs ~field (a : Wire_v2.Attack.t option) =
  Option.bind a ~f:(fun a ->
    let accurate =
      bounded
        repairs
        ~field:[%string "%{field}.accurate"]
        ~of_int:Attribute_value.of_int
        ~clamp:Attribute_value.of_int_clamped
        ~to_int:Attribute_value.to_int
        a.accurate
    in
    let source =
      match a.estimated_from with
      | None -> Attack_profile.Source.From_data
      | Some band ->
        (match Option.try_with (fun () -> Resistance.of_string band) with
         | Some resistance -> Estimated_from_resistance resistance
         | None ->
           Repairs.add
             repairs
             (Field_unreadable
                { field = [%string "%{field}.estimated_from"]; value = band });
           From_data)
    in
    match
      Dice.create ~count:a.damage.count ~sides:a.damage.sides ~modifier:a.damage.modifier
    with
    | Ok damage -> Some (Attack_profile.create ~accurate ~damage ~source)
    | Error _ ->
      (* No damage die means no attack profile. Dropping it is right: an attack
         that cannot say what it does is worse than no attack, because the model
         would quietly read a default. *)
      Repairs.add
        repairs
        (Field_unreadable
           { field = [%string "%{field}.damage"]
           ; value =
               [%string
                 "%{a.damage.count#Int}d%{a.damage.sides#Int}+%{a.damage.modifier#Int}"]
           });
      None)
;;

(* An id or a name that {!Core.String_id} refuses -- empty, or edge whitespace --
   is replaced rather than dropped. Losing a combatant out of a saved fight is
   the one outcome worse than renaming one. *)
let string_id repairs ~field ~of_string ~fallback given =
  match Option.try_with (fun () -> of_string given) with
  | Some id -> id
  | None ->
    Repairs.add repairs (Field_unreadable { field; value = given });
    of_string fallback
;;

let name repairs ~field given =
  string_id repairs ~field ~of_string:Name.of_string ~fallback:"Unnamed" given
;;

let character repairs index (c : Wire_v2.Character.t) : Character.t =
  let at = [%string "characters[%{index#Int}]"] in
  { id =
      string_id
        repairs
        ~field:[%string "%{at}.id"]
        ~of_string:Ids.Character_id.of_string
        ~fallback:[%string "imported_character_%{index#Int}"]
        c.id
  ; name = name repairs ~field:[%string "%{at}.name"] c.name
  ; role = c.role
  ; initiative = initiative repairs ~field:[%string "%{at}.initiative"] c.initiative
  ; toughness = toughness repairs ~field:[%string "%{at}.toughness"] c.toughness
  ; defense = defense repairs ~field:[%string "%{at}.defense"] c.defense
  ; armor = armor c.armor
  ; pain_threshold = Pain_threshold.of_int_option c.pain_threshold
  ; attributes = attributes repairs ~field:[%string "%{at}.attributes"] c.attributes
  ; note = c.note
  ; is_builtin = c.is_builtin
  }
;;

(* Whether a combatant pointing at a missing character is repaired here.

   The live encounter is subject to {!World.invariant} and so is [Demote_against]
   the roster. An archived one is a {i snapshot} of what a fight looked like, and
   demoting a player character inside a snapshot rewrites history -- so it is
   [Keep], and {!World.apply}'s [Restore_encounter] deals with the orphan on the
   way out. That is the right moment, because it is when the combatant re-enters
   the world the invariant is about.

   The round-trip property is what forced this distinction: clear a fight, then
   delete a character who was in it, and the archive legitimately holds an orphan
   that the file must be able to carry back unchanged. *)
type orphans =
  | Demote_against of Roster.t
  | Keep

let allegiance
      ~orphans
      ~name:combatant_name
      repairs
      ~field
      (a : Wire_v2.Combatant.Allegiance.t)
  : Combatant.Allegiance.t
  =
  match a with
  | Non_player monster_type ->
    Non_player (Option.map monster_type ~f:Monster_type.of_string)
  | Player_character id ->
    let id =
      string_id
        repairs
        ~field
        ~of_string:Ids.Character_id.of_string
        ~fallback:"imported_orphan"
        id
    in
    (match orphans with
     | Keep -> Player_character id
     | Demote_against roster ->
       if Roster.mem roster id
       then Player_character id
       else (
         (* Demoting rather than deleting: taking a combatant out of a fight the
            GM is in the middle of is the worse repair. *)
         Repairs.add
           repairs
           (Orphan_player_character
              { name = Name.to_string combatant_name
              ; missing = Ids.Character_id.to_string id
              });
         Non_player None))
;;

let combatant ~orphans repairs ~at index (c : Wire_v2.Combatant.t) : Combatant.t =
  let at = [%string "%{at}[%{index#Int}]"] in
  let combatant_name = name repairs ~field:[%string "%{at}.name"] c.name in
  { id =
      string_id
        repairs
        ~field:[%string "%{at}.id"]
        ~of_string:Ids.Combatant_id.of_string
        ~fallback:[%string "imported_combatant_%{index#Int}"]
        c.id
  ; allegiance =
      allegiance
        ~orphans
        ~name:combatant_name
        repairs
        ~field:[%string "%{at}.allegiance"]
        c.allegiance
  ; name = combatant_name
  ; initiative = initiative repairs ~field:[%string "%{at}.initiative"] c.initiative
  ; toughness = toughness repairs ~field:[%string "%{at}.toughness"] c.toughness
  ; defense = defense repairs ~field:[%string "%{at}.defense"] c.defense
  ; armor = armor c.armor
  ; pain_threshold = Pain_threshold.of_int_option c.pain_threshold
  ; prone = c.prone
  ; flanked = c.flanked
  ; attributes = attributes repairs ~field:[%string "%{at}.attributes"] c.attributes
  ; attack = attack repairs ~field:[%string "%{at}.attack"] c.attack
  ; note = c.note
  }
;;

(* [None] -- the field absent -- means "this save predates the counter, rebuild
   it from the names present". [Some []] means the counter is genuinely empty.
   See the note in {!Wire_v2.Encounter}: collapsing the two is a round trip that
   changes the value. *)
let name_counter (marks : (string * int) list option) =
  Option.map marks ~f:(fun marks ->
    List.fold marks ~init:Name_counter.empty ~f:(fun acc (monster_type, n) ->
      Name_counter.reserve acc (Monster_type.of_string monster_type) n))
;;

let encounter ~orphans repairs ~at (e : Wire_v2.Encounter.t) =
  let members =
    List.mapi e.members ~f:(fun i member ->
      combatant ~orphans repairs ~at:[%string "%{at}.members"] i member)
  in
  let encounter, normalizations =
    Encounter.create
      ~members
      ~turn_index:e.turn_index
      ~round:e.round
      ~name_counter:(name_counter e.name_counter)
  in
  Repairs.add_all repairs normalizations;
  encounter
;;

let bestiary_entry repairs index (e : Wire_v2.Bestiary_entry.t) : Bestiary.Entry.t =
  let at = [%string "bestiary[%{index#Int}]"] in
  { id =
      string_id
        repairs
        ~field:[%string "%{at}.id"]
        ~of_string:Ids.Bestiary_id.of_string
        ~fallback:[%string "imported_bestiary_%{index#Int}"]
        e.id
  ; monster_type =
      string_id
        repairs
        ~field:[%string "%{at}.monster_type"]
        ~of_string:Monster_type.of_string
        ~fallback:"Unnamed"
        e.monster_type
  ; initiative = initiative repairs ~field:[%string "%{at}.initiative"] e.initiative
  ; toughness = toughness repairs ~field:[%string "%{at}.toughness"] e.toughness
  ; defense = defense repairs ~field:[%string "%{at}.defense"] e.defense
  ; armor = armor e.armor
  ; pain_threshold = Pain_threshold.of_int_option e.pain_threshold
  ; attributes = attributes repairs ~field:[%string "%{at}.attributes"] e.attributes
  ; attack = attack repairs ~field:[%string "%{at}.attack"] e.attack
  ; note = e.note
  ; updated_at = ms_to_time e.updated_at_ms
  }
;;

let archive_entry repairs index (e : Wire_v2.Archive_entry.t) : Encounter_archive.Entry.t =
  let at = [%string "archive[%{index#Int}]"] in
  { id =
      string_id
        repairs
        ~field:[%string "%{at}.id"]
        ~of_string:Ids.Snapshot_id.of_string
        ~fallback:[%string "imported_snapshot_%{index#Int}"]
        e.id
  ; at = ms_to_time e.at_ms
  ; label = e.label
  ; encounter =
      encounter ~orphans:Keep repairs ~at:[%string "%{at}.encounter"] e.encounter
  }
;;

let to_domain (t : Wire_v2.t) =
  let repairs = Repairs.create () in
  let roster, roster_repairs =
    Roster.of_list (List.mapi t.characters ~f:(character repairs))
  in
  Repairs.add_all repairs roster_repairs;
  let encounter =
    encounter ~orphans:(Demote_against roster) repairs ~at:"encounter" t.encounter
  in
  let bestiary = Bestiary.of_list (List.mapi t.bestiary ~f:(bestiary_entry repairs)) in
  let archive =
    Encounter_archive.of_list (List.mapi t.archive ~f:(archive_entry repairs))
  in
  { World.roster; encounter; bestiary; archive }, Repairs.to_list repairs
;;

(* The easy direction. Every field is already a type that cannot hold a bad
   value, so there is nothing to check and nothing to report. *)

let of_attributes attributes : Wire_v2.Attributes.t =
  let score attribute =
    Option.map (Attributes.find attributes attribute) ~f:Attribute_value.to_int
  in
  { acc = score Accurate
  ; cun = score Cunning
  ; dis = score Discreet
  ; per = score Persuasive
  ; qui = score Quick
  ; res = score Resolute
  ; str = score Strong
  ; vig = score Vigilant
  }
;;

let of_toughness (t : Toughness.t) : Wire_v2.Toughness.t =
  { current = t.current; max = t.max }
;;

let of_attack (a : Attack_profile.t option) : Wire_v2.Attack.t option =
  Option.map a ~f:(fun a ->
    { Wire_v2.Attack.accurate = Attribute_value.to_int a.accurate
    ; damage =
        { count = a.damage.count; sides = a.damage.sides; modifier = a.damage.modifier }
    ; estimated_from =
        (match a.source with
         | From_data -> None
         | Estimated_from_resistance resistance -> Some (Resistance.to_string resistance))
    })
;;

let of_character (c : Character.t) : Wire_v2.Character.t =
  { id = Ids.Character_id.to_string c.id
  ; name = Name.to_string c.name
  ; role = c.role
  ; initiative = Initiative.to_int c.initiative
  ; toughness = of_toughness c.toughness
  ; defense = Defense.to_int c.defense
  ; armor = c.armor.text
  ; pain_threshold = Pain_threshold.to_int_option c.pain_threshold
  ; attributes = of_attributes c.attributes
  ; note = c.note
  ; is_builtin = c.is_builtin
  }
;;

let of_combatant (c : Combatant.t) : Wire_v2.Combatant.t =
  { id = Ids.Combatant_id.to_string c.id
  ; allegiance =
      (match c.allegiance with
       | Player_character id -> Player_character (Ids.Character_id.to_string id)
       | Non_player monster_type ->
         Non_player (Option.map monster_type ~f:Monster_type.to_string))
  ; name = Name.to_string c.name
  ; initiative = Initiative.to_int c.initiative
  ; toughness = of_toughness c.toughness
  ; defense = Defense.to_int c.defense
  ; armor = c.armor.text
  ; pain_threshold = Pain_threshold.to_int_option c.pain_threshold
  ; prone = c.prone
  ; flanked = c.flanked
  ; attributes = of_attributes c.attributes
  ; attack = of_attack c.attack
  ; note = c.note
  }
;;

let of_encounter encounter : Wire_v2.Encounter.t =
  { members = List.map (Encounter.members encounter) ~f:of_combatant
  ; turn_index = Option.value (Encounter.turn_index encounter) ~default:0
  ; round = Round.to_int (Encounter.round encounter)
  ; name_counter =
      Some
        (List.map
           (Name_counter.to_alist (Encounter.name_counter encounter))
           ~f:(fun (monster_type, n) -> Monster_type.to_string monster_type, n))
  }
;;

let of_bestiary_entry (e : Bestiary.Entry.t) : Wire_v2.Bestiary_entry.t =
  { id = Ids.Bestiary_id.to_string e.id
  ; monster_type = Monster_type.to_string e.monster_type
  ; initiative = Initiative.to_int e.initiative
  ; toughness = of_toughness e.toughness
  ; defense = Defense.to_int e.defense
  ; armor = e.armor.text
  ; pain_threshold = Pain_threshold.to_int_option e.pain_threshold
  ; attributes = of_attributes e.attributes
  ; attack = of_attack e.attack
  ; note = e.note
  ; updated_at_ms = time_to_ms e.updated_at
  }
;;

let of_archive_entry (e : Encounter_archive.Entry.t) : Wire_v2.Archive_entry.t =
  { id = Ids.Snapshot_id.to_string e.id
  ; at_ms = time_to_ms e.at
  ; label = e.label
  ; encounter = of_encounter e.encounter
  }
;;

let of_domain (world : World.t) : Wire_v2.t =
  { version = Wire_v2.version
  ; characters = List.map (Roster.to_list world.roster) ~f:of_character
  ; encounter = of_encounter world.encounter
  ; bestiary = List.map (Bestiary.to_list world.bestiary) ~f:of_bestiary_entry
  ; archive = List.map (Encounter_archive.to_list world.archive) ~f:of_archive_entry
  }
;;
