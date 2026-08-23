open! Core

module Category =
  String_id.Make
    (struct
      let module_name = "Symbaroum.Monster_preset.Category"
    end)
    ()

module Raw = struct
  type t =
    { name : string
    ; category : string
    ; resistance : string
    ; toughness : int option
    ; defense : int option
    ; armor : string option
    ; pain_threshold : int option
    ; attributes : (string * int option) list
    }
  [@@deriving compare, equal, sexp_of]
end

module Defense_reading = struct
  type t =
    | Stored_modifier
    | Derived_from_quick
    | Unknown
  [@@deriving compare, equal, enumerate, sexp_of, quickcheck]
end

type t =
  { name : Monster_type.t
  ; category : Category.t
  ; resistance : Resistance.t
  ; toughness : Toughness.t option
  ; defense : Defense.t option
  ; defense_raw : int option
  ; defense_reading : Defense_reading.t
  ; armor : Armor.t
  ; pain_threshold : Pain_threshold.t
  ; attributes : Attributes.t
  ; attack : Attack_profile.t option
  ; caveats : Caveat.t list
  }
[@@deriving compare, equal, sexp_of]

let attributes_of_alist alist =
  let open Or_error.Let_syntax in
  let%bind pairs =
    List.map alist ~f:(fun (key, value) ->
      let%bind attribute =
        match Attribute.of_key key with
        | Some attribute -> Ok attribute
        | None -> Or_error.error_s [%message "unknown attribute key" (key : string)]
      in
      let%map value =
        match value with
        | None -> Ok None
        | Some n -> Or_error.map (Attribute_value.of_int n) ~f:Option.some
      in
      attribute, value)
    |> Or_error.all
  in
  Attributes.of_alist pairs
;;

(* The ruling: the stored field is a modifier, so the roll-under target is
   [10 - defense]. Where that is not a legal target -- five presets in the
   shipped data, all of them the absolute-target spelling -- fall back to Quick,
   which every preset has and which is what defence derives from in the rules
   anyway. Either way the original number survives in [defense_raw], so the
   golden test shows the substitution instead of hiding it. *)
let reconcile_defense ~stored ~quick =
  let derived reason =
    match quick with
    | Some quick ->
      ( Some (Defense.of_quick quick)
      , Defense_reading.Derived_from_quick
      , [ Caveat.Defense_derived_from_quick reason ] )
    | None -> None, Defense_reading.Unknown, [ Caveat.Defense_derived_from_quick reason ]
  in
  match stored with
  | None -> derived None
  | Some stored ->
    (match Defense.of_modifier stored with
     | Ok defense -> Some defense, Defense_reading.Stored_modifier, []
     | Error _ -> derived (Some stored))
;;

let of_raw (raw : Raw.t) =
  let open Or_error.Let_syntax in
  let%bind name = Or_error.try_with (fun () -> Monster_type.of_string raw.name) in
  let%bind category = Or_error.try_with (fun () -> Category.of_string raw.category) in
  let%bind resistance =
    Or_error.try_with (fun () -> Resistance.of_string raw.resistance)
  in
  let%bind attributes = attributes_of_alist raw.attributes in
  let%map toughness =
    match raw.toughness with
    | None -> Ok None
    | Some n -> Or_error.map (Toughness.full n) ~f:Option.some
  in
  let defense, defense_reading, defense_caveats =
    reconcile_defense
      ~stored:raw.defense
      ~quick:(Attributes.find attributes Attribute.Quick)
  in
  let armor = Armor.parse (Option.value raw.armor ~default:"") in
  let attack =
    Option.map (Attributes.find attributes Attribute.Accurate) ~f:(fun accurate ->
      Attack_profile.estimate ~accurate ~resistance)
  in
  (* Fixed order, so the golden dump is stable and a diff means something. *)
  let caveats =
    List.concat
      [ (if Option.is_none toughness then [ Caveat.No_toughness ] else [])
      ; defense_caveats
      ; (if Armor.is_unparsed armor then [ Caveat.Armor_unparsed armor.text ] else [])
      ; (match attack with
         | Some _ -> [ Caveat.Damage_die_estimated resistance ]
         | None -> [ Caveat.No_attack_profile ])
      ]
  in
  { name
  ; category
  ; resistance
  ; toughness
  ; defense
  ; defense_raw = raw.defense
  ; defense_reading
  ; armor
  ; pain_threshold = Pain_threshold.of_int_option raw.pain_threshold
  ; attributes
  ; attack
  ; caveats
  }
;;

let initiative t =
  match Attributes.find t.attributes Attribute.Quick with
  | None -> Initiative.zero
  | Some quick -> Initiative.of_int_clamped (Attribute_value.to_int quick)
;;

let is_modellable t =
  Option.is_some t.toughness && Option.is_some t.defense && Option.is_some t.attack
;;
