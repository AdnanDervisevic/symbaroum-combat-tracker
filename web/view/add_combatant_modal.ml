(** The Manage Combatants dialog: send player characters in, build NPCs, reuse a stat block, bring a cleared fight back. *)

open! Core
open Bonsai_web
open Symbaroum

module Source = struct
  (** Where the attributes and the attack came from. The form cannot hold them
      as strings, and they are exactly the block
      {{:src/App.tsx} [addNpc]} drops on the floor -- so the form remembers
      {i where to look} and {!Form.to_draft} fetches them at submit time. *)
  type t =
    | Blank
    | Preset of string
    | Bestiary of string
  [@@deriving sexp, equal]

  let to_string = function
    | Blank -> ""
    | Preset name -> name
    | Bestiary name -> name
  ;;
end

module Form = struct
  type t =
    { source : Source.t
    ; monster_type : string
    ; name : string
    ; count : string
    ; initiative : string
    ; toughness : string
    ; defense : string
    ; armor : string
    ; pain_threshold : string
    ; note : string
    }
  [@@deriving sexp, equal]

  let of_draft ~source (d : Npc_draft.t) =
    { source
    ; monster_type = Option.value_map d.monster_type ~default:"" ~f:Monster_type.to_string
    ; name = Option.value_map d.name ~default:"" ~f:Name.to_string
    ; count = Int.to_string (Npc_count.to_int d.count)
    ; initiative = Int.to_string (Initiative.to_int d.initiative)
    ; toughness = Int.to_string d.toughness.max
    ; defense = Int.to_string (Defense.to_int d.defense)
    ; armor = d.armor.text
    ; pain_threshold =
        Option.value_map
          (Pain_threshold.to_int_option d.pain_threshold)
          ~default:""
          ~f:Int.to_string
    ; note = d.note
    }
  ;;

  let blank = of_draft ~source:Blank Npc_draft.default

  (** [None] when a number will not parse or the domain refuses it. The button is
      disabled in that case, so the user is told rather than surprised. *)
  let to_draft t ~bestiary =
    let int s = Int.of_string_opt (String.strip s) in
    let attributes, attack =
      match t.source with
      | Blank -> Attributes.empty, None
      | Preset name ->
        (match Monster_presets.find (Monster_type.of_string name) with
         | Some preset -> preset.attributes, preset.attack
         | None -> Attributes.empty, None)
      | Bestiary name ->
        (match Bestiary.find bestiary (Monster_type.of_string name) with
         | Some entry -> entry.attributes, entry.attack
         | None -> Attributes.empty, None)
    in
    let open Option.Let_syntax in
    let%bind count =
      Option.bind (int t.count) ~f:(fun n -> Or_error.ok (Npc_count.of_int n))
    in
    let%bind initiative =
      Option.bind (int t.initiative) ~f:(fun n -> Or_error.ok (Initiative.of_int n))
    in
    let%bind toughness =
      Option.bind (int t.toughness) ~f:(fun n -> Or_error.ok (Toughness.full n))
    in
    let%map defense =
      Option.bind (int t.defense) ~f:(fun n -> Or_error.ok (Defense.of_target n))
    in
    { Npc_draft.monster_type =
        (match String.strip t.monster_type with
         | "" -> None
         | s -> Some (Monster_type.of_string s))
    ; name =
        (match String.strip t.name with
         | "" -> None
         | s -> Option.try_with (fun () -> Name.of_string s))
    ; count
    ; initiative
    ; toughness
    ; defense
    ; armor = Armor.parse t.armor
    ; pain_threshold = Pain_threshold.of_int_option (int t.pain_threshold)
    ; attributes
    ; attack
    ; note = t.note
    }
  ;;
end

module Selection = struct
  (** Which player characters are ticked.

      A state {i machine} rather than a {!Bonsai.state}, and the difference is
      not stylistic. A [Bonsai.state] setter takes the new value, so a handler
      has to close over the old one -- and two clicks that land before a render
      both read the same old set, so the second overwrites the first instead of
      adding to it. Ticking four boxes quickly put one character in the fight.
      An action says {i what to do} rather than {i what the answer is}, and is
      applied to whatever the model actually holds. *)
  module Model = struct
    type t = Set.M(Ids.Character_id).t [@@deriving sexp, equal]
  end

  module Action = struct
    type t = Toggle of Ids.Character_id.t [@@deriving sexp_of]
  end

  let empty = Set.empty (module Ids.Character_id)

  let component =
    Bonsai.state_machine0
      (module Model)
      (module Action)
      ~default_model:empty
      ~apply_action:(fun ~inject:_ ~schedule_event:_ model (Toggle id) ->
        if Set.mem model id then Set.remove model id else Set.add model id)
  ;;
end

let field ~label ~value ~on_change =
  Ui.labelled ~label (Ui.text_input ~value ~on_change ())
;;

let pc_picker ~(world : World.t) ~selected ~toggle ~inject =
  let already_in =
    Ids.Character_id.Set.of_list
      (List.filter_map (Encounter.members world.encounter) ~f:(fun (c : Combatant.t) ->
         Combatant.Allegiance.character_id c.allegiance))
  in
  let available =
    List.filter (Roster.to_list world.roster) ~f:(fun (c : Character.t) ->
      not (Set.mem already_in c.id))
  in
  Vdom.Node.div
    ~attrs:[ Vdom.Attr.class_ "modal-section" ]
    [ Vdom.Node.h3 [ Ui.text "Player Characters" ]
    ; (match available with
       | [] -> Ui.muted ~small:true [ Ui.text "Everyone on the roster is already in." ]
       | available ->
         Vdom.Node.div
           ~attrs:[ Vdom.Attr.class_ "pc-picker" ]
           (List.map available ~f:(fun (c : Character.t) ->
              Ui.checkbox
                ~label:(Name.to_string c.name)
                ~checked:(Set.mem selected c.id)
                ~on_change:(fun (_ : bool) -> toggle c.id))))
    ; Vdom.Node.div
        ~attrs:[ Vdom.Attr.class_ "modal-actions" ]
        [ Ui.button
            ~disabled:(Set.is_empty selected)
            ~on_click:(inject (App_state.Action.Send_to_fight (Set.to_list selected)))
            "Add Selected"
        ; Ui.button
            ~classes:[ "danger"; "ghost" ]
            ~on_click:(inject App_state.Action.Clear_encounter)
            "Clear Encounter"
        ]
    ]
;;

let npc_form ~form ~set_form ~bestiary ~inject =
  let set f = set_form f in
  let text ~label ~get ~put =
    field ~label ~value:(get form) ~on_change:(fun s -> set (put form s))
  in
  let draft = Form.to_draft form ~bestiary in
  Vdom.Node.div
    ~attrs:[ Vdom.Attr.class_ "modal-section" ]
    [ Vdom.Node.h3 [ Ui.text "NPCs" ]
    ; Vdom.Node.div
        ~attrs:[ Vdom.Attr.class_ "preset-row" ]
        [ Vdom.Node.label
            ~attrs:[ Vdom.Attr.class_ "preset-label" ]
            [ Vdom.Node.span [ Ui.text "Preset" ]
            ; Vdom.Node.select
                ~attrs:
                  [ Vdom.Attr.class_ "preset-select"
                  ; Vdom.Attr.value_prop (Source.to_string form.source)
                  ; Vdom.Attr.on_change (fun _ chosen ->
                      match Monster_presets.find (Monster_type.of_string chosen) with
                      | None -> set Form.blank
                      | Some preset ->
                        set
                          (Form.of_draft
                             ~source:(Preset chosen)
                             (Npc_draft.of_preset preset)))
                  ]
                (Vdom.Node.option ~attrs:[ Vdom.Attr.value_prop "" ] [ Ui.text "(none)" ]
                 :: List.map Monster_presets.all ~f:(fun (p : Monster_preset.t) ->
                   let name = Monster_type.to_string p.name in
                   Vdom.Node.option ~attrs:[ Vdom.Attr.value_prop name ] [ Ui.text name ])
                )
            ]
        ]
    ; Vdom.Node.div
        ~attrs:[ Vdom.Attr.classes [ "inline-form"; "labeled" ] ]
        [ text
            ~label:"Type"
            ~get:(fun f -> f.Form.monster_type)
            ~put:(fun f s -> { f with Form.monster_type = s })
        ; text
            ~label:"Name"
            ~get:(fun f -> f.Form.name)
            ~put:(fun f s -> { f with Form.name = s })
        ; text
            ~label:"Count"
            ~get:(fun f -> f.Form.count)
            ~put:(fun f s -> { f with Form.count = s })
        ; text
            ~label:"Init"
            ~get:(fun f -> f.Form.initiative)
            ~put:(fun f s -> { f with Form.initiative = s })
        ; text
            ~label:"Toughness"
            ~get:(fun f -> f.Form.toughness)
            ~put:(fun f s -> { f with Form.toughness = s })
        ; text
            ~label:"Defense"
            ~get:(fun f -> f.Form.defense)
            ~put:(fun f s -> { f with Form.defense = s })
        ; text
            ~label:"Armor"
            ~get:(fun f -> f.Form.armor)
            ~put:(fun f s -> { f with Form.armor = s })
        ; text
            ~label:"Pain Th."
            ~get:(fun f -> f.Form.pain_threshold)
            ~put:(fun f s -> { f with Form.pain_threshold = s })
        ]
    ; Ui.textarea
        ~placeholder:"Notes"
        ~value:form.Form.note
        ~on_change:(fun note -> set { form with Form.note })
        ()
    ; Vdom.Node.div
        ~attrs:[ Vdom.Attr.class_ "modal-actions" ]
        [ Ui.button
            ~disabled:(Option.is_none draft)
            ~on_click:
              (match draft with
               | None -> Effect.Ignore
               | Some draft -> inject (App_state.Action.Add_npcs draft))
            "Add NPC"
        ]
    ; (match draft with
       | Some _ -> Vdom.Node.none
       | None ->
         Ui.muted
           ~small:true
           [ Ui.text
               "One of the numbers above is not a value this app can hold, so nothing \
                will be added until it is fixed."
           ])
    ]
;;

let bestiary_section ~(bestiary : Bestiary.t) ~set_form ~inject =
  Vdom.Node.div
    ~attrs:[ Vdom.Attr.class_ "modal-section" ]
    [ Vdom.Node.h3 [ Ui.text "Bestiary" ]
    ; (match Bestiary.to_list bestiary with
       | [] -> Ui.muted ~small:true [ Ui.text "Stat blocks you use get saved here." ]
       | entries ->
         Vdom.Node.div
           ~attrs:[ Vdom.Attr.class_ "bestiary-list" ]
           (List.map entries ~f:(fun (e : Bestiary.Entry.t) ->
              let name = Monster_type.to_string e.monster_type in
              Vdom.Node.div
                ~attrs:[ Vdom.Attr.class_ "bestiary-item" ]
                [ Vdom.Node.div
                    ~attrs:[ Vdom.Attr.class_ "bestiary-info" ]
                    [ Ui.text
                        [%string
                          "%{name} \u{2014} T%{e.toughness.max#Int}, def \
                           %{Defense.to_int e.defense#Int}"]
                    ]
                ; Vdom.Node.div
                    ~attrs:[ Vdom.Attr.class_ "bestiary-actions" ]
                    [ Ui.button
                        ~on_click:
                          (set_form
                             (Form.of_draft
                                ~source:(Bestiary name)
                                (Npc_draft.of_bestiary_entry e)))
                        "Load"
                    ; Ui.button
                        ~classes:[ "danger"; "ghost" ]
                        ~on_click:
                          (inject
                             (App_state.Action.Apply (Delete_bestiary_entry { id = e.id })))
                        "Delete"
                    ]
                ])))
    ]
;;

let archive_section ~(archive : Encounter_archive.t) ~inject =
  Vdom.Node.div
    ~attrs:[ Vdom.Attr.class_ "modal-section" ]
    [ Vdom.Node.h3 [ Ui.text "Saved Encounters" ]
    ; (match Encounter_archive.to_list archive with
       | [] -> Ui.muted ~small:true [ Ui.text "Cleared fights are kept here." ]
       | entries ->
         Vdom.Node.div
           ~attrs:[ Vdom.Attr.class_ "history-list" ]
           (List.map entries ~f:(fun (e : Encounter_archive.Entry.t) ->
              Vdom.Node.div
                ~attrs:[ Vdom.Attr.class_ "history-item" ]
                [ Vdom.Node.div
                    ~attrs:[ Vdom.Attr.class_ "history-info" ]
                    [ Ui.text e.label ]
                ; Vdom.Node.div
                    ~attrs:[ Vdom.Attr.class_ "history-actions" ]
                    [ Ui.button
                        ~on_click:
                          (inject
                             (App_state.Action.Apply (Restore_encounter { id = e.id })))
                        "Restore"
                    ; Ui.button
                        ~classes:[ "danger"; "ghost" ]
                        ~on_click:
                          (inject
                             (App_state.Action.Apply (Delete_snapshot { id = e.id })))
                        "Delete"
                    ]
                ])))
    ]
;;

let render ~world ~form ~set_form ~selected ~toggle ~inject ~close =
  Vdom.Node.div
    ~attrs:[ Vdom.Attr.class_ "modal-overlay" ]
    [ Vdom.Node.div
        ~attrs:[ Vdom.Attr.class_ "modal" ]
        [ Vdom.Node.div
            ~attrs:[ Vdom.Attr.class_ "modal-header" ]
            [ Vdom.Node.h2 [ Ui.text "Manage Combatants" ]
            ; Ui.button ~classes:[ "ghost" ] ~on_click:close "Close"
            ]
        ; Vdom.Node.div
            ~attrs:[ Vdom.Attr.class_ "modal-body" ]
            [ pc_picker ~world ~selected ~toggle ~inject
            ; npc_form ~form ~set_form ~bestiary:world.World.bestiary ~inject
            ; bestiary_section ~bestiary:world.World.bestiary ~set_form ~inject
            ; archive_section ~archive:world.World.archive ~inject
            ]
        ]
    ]
;;

let component ~world ~inject ~close =
  let open Bonsai.Let_syntax in
  let%sub form, set_form = Bonsai.state (module Form) ~default_model:Form.blank in
  let%sub selected, inject_selection = Selection.component in
  let%sub toggle =
    let%arr inject_selection = inject_selection in
    fun id -> inject_selection (Selection.Action.Toggle id)
  in
  let%arr world = world
  and form = form
  and set_form = set_form
  and selected = selected
  and toggle = toggle
  and inject = inject
  and close = close in
  render ~world ~form ~set_form ~selected ~toggle ~inject ~close
;;
