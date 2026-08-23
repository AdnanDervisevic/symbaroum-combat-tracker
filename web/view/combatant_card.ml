(** One combatant in the fight, and the only card with state of its own.

    That state is the point. The React app keeps [damageInputs] and [editingIds]
    as root-level records keyed by combatant id, and prunes them only in
    [removeMember] and only for [editingIds] -- so **[damageInputs] leaks an
    entry for every combatant that ever existed**, for as long as the tab is
    open.

    Here the two pieces of state are created by {!Bonsai.assoc} {i with} the row
    and destroyed with it. The leak is not fixed; it is structurally
    unrepresentable, because there is no root-level map to leave an entry in. *)

open! Core
open Bonsai_web
open Symbaroum

let patch inject id p = inject (App_state.Action.Apply (Update_member { id; patch = p }))

let optional_patch inject id p =
  match p with
  | Some p -> patch inject id p
  | None -> Effect.Ignore
;;

let attribute_cells (attributes : Attributes.t) =
  match Attributes.to_known_alist attributes with
  | [] -> Vdom.Node.none
  | known ->
    Vdom.Node.div
      ~attrs:[ Vdom.Attr.class_ "attr-row" ]
      (List.map known ~f:(fun (attribute, value) ->
         let modifier = Attribute_value.modifier value in
         Vdom.Node.div
           ~attrs:
             [ Vdom.Attr.class_ "attr-cell"
             ; Vdom.Attr.create "data-attr" (Attribute.to_key attribute)
             ]
           [ Vdom.Node.span [ Ui.text (Attribute.to_label attribute) ]
           ; Vdom.Node.strong
               [ Ui.text
                   (if modifier > 0
                    then [%string "+%{modifier#Int}"]
                    else Int.to_string modifier)
               ]
           ]))
;;

let render ~inject ~is_active ~editing ~set_editing ~amount ~set_amount (c : Combatant.t) =
  let id = c.id in
  let set p = patch inject id p in
  let try_set p = optional_patch inject id p in
  let stat ~label ~value ~on_change =
    Ui.labelled
      ~classes:[ "stat-field" ]
      ~label
      (Ui.number_input ~readonly:(not editing) ~value ~on_change ())
  in
  Vdom.Node.div
    ~attrs:
      [ Vdom.Attr.classes
          (if is_active
           then [ "card"; "encounter-card"; "active" ]
           else [ "card"; "encounter-card" ])
      ]
    [ Vdom.Node.div
        ~attrs:[ Vdom.Attr.classes [ "card-line"; "compact-header" ] ]
        [ Vdom.Node.div
            ~attrs:[ Vdom.Attr.class_ "name-wrapper" ]
            [ Ui.text_input
                ~classes:[ "name" ]
                ~readonly:(not editing)
                ~value:(Name.to_string c.name)
                ~on_change:(fun typed ->
                  match Option.try_with (fun () -> Name.of_string typed) with
                  | Some name -> set (Set_name name)
                  | None -> Effect.Ignore)
                ()
            ; (match c.allegiance with
               | Non_player (Some monster_type) ->
                 Vdom.Node.span
                   ~attrs:[ Vdom.Attr.class_ "monster-type-badge" ]
                   [ Ui.text (Monster_type.to_string monster_type) ]
               | Non_player None | Player_character _ -> Vdom.Node.none)
            ]
        ; Vdom.Node.div
            ~attrs:[ Vdom.Attr.class_ "order-buttons" ]
            [ Ui.button
                ~classes:[ "icon" ]
                ~on_click:
                  (inject (App_state.Action.Apply (Move_member { id; direction = `Up })))
                "\u{2191}"
            ; Ui.button
                ~classes:[ "icon" ]
                ~on_click:
                  (inject
                     (App_state.Action.Apply (Move_member { id; direction = `Down })))
                "\u{2193}"
            ]
        ]
    ; Vdom.Node.div
        ~attrs:[ Vdom.Attr.class_ "stat-block" ]
        [ Vdom.Node.div
            ~attrs:[ Vdom.Attr.classes [ "stat-row"; "single-line" ] ]
            [ stat
                ~label:"Init"
                ~value:(Int.to_string (Initiative.to_int c.initiative))
                ~on_change:(fun n ->
                  try_set
                    (Option.bind n ~f:(fun n ->
                       Ui.guarded
                         ~of_int:Initiative.of_int
                         ~f:(fun i -> Member_patch.Set_initiative i)
                         n)))
              (* Current out of maximum, which v1 could not hold: its single
                 [toughness] was both at once. *)
            ; stat
                ~label:"Tough"
                ~value:(Int.to_string c.toughness.current)
                ~on_change:(fun n ->
                  try_set
                    (Option.bind n ~f:(fun current ->
                       match Toughness.create ~current ~max:c.toughness.max with
                       | Ok t -> Some (Member_patch.Set_toughness t)
                       | Error _ -> None)))
            ; stat
                ~label:"Max"
                ~value:(Int.to_string c.toughness.max)
                ~on_change:(fun n ->
                  try_set (Option.map n ~f:(fun n -> Member_patch.Set_max_toughness n)))
            ; stat
                ~label:"Def"
                ~value:(Int.to_string (Defense.to_int c.defense))
                ~on_change:(fun n ->
                  try_set
                    (Option.bind n ~f:(fun n ->
                       Ui.guarded
                         ~of_int:Defense.of_target
                         ~f:(fun d -> Member_patch.Set_defense d)
                         n)))
            ; Ui.labelled
                ~classes:[ "stat-field" ]
                ~label:"Armor"
                (Ui.text_input
                   ~readonly:(not editing)
                   ~value:c.armor.text
                   ~on_change:(fun text -> set (Set_armor (Armor.parse text)))
                   ())
            ; stat
                ~label:"Pain Th."
                ~value:
                  (Option.value_map
                     (Pain_threshold.to_int_option c.pain_threshold)
                     ~default:""
                     ~f:Int.to_string)
                ~on_change:(fun n ->
                  set (Set_pain_threshold (Pain_threshold.of_int_option n)))
            ]
        ]
    ; attribute_cells c.attributes
    ; Vdom.Node.div
        ~attrs:[ Vdom.Attr.class_ "status-row" ]
        [ Ui.checkbox ~label:"Prone" ~checked:c.prone ~on_change:(fun prone ->
            set (Set_prone prone))
        ; Ui.checkbox ~label:"Flanked" ~checked:c.flanked ~on_change:(fun flanked ->
            set (Set_flanked flanked))
        ]
    ; Vdom.Node.div
        ~attrs:[ Vdom.Attr.classes [ "adjust-row"; "inline" ] ]
        [ Ui.labelled
            ~classes:[ "amount-inline" ]
            ~label:"Amount"
            (Ui.number_input
               ~value:(Int.to_string amount)
               ~on_change:(fun n -> set_amount (Option.value n ~default:0))
               ())
        ; Vdom.Node.div
            ~attrs:[ Vdom.Attr.class_ "adjust-buttons" ]
            (List.map
               [ `Heal, "Heal"; `Hurt, "Hurt" ]
               ~f:(fun (mode, label) ->
                 Ui.button
                   ~on_click:
                     (match Adjust_amount.of_int amount with
                      | Ok amount ->
                        inject (App_state.Action.Apply (Adjust { id; amount; mode }))
                      | Error _ -> Effect.Ignore)
                   label))
        ]
    ; Ui.textarea
        ~placeholder:"Notes / conditions"
        ~value:c.note
        ~on_change:(fun note -> set (Set_note note))
        ()
    ; Vdom.Node.div
        ~attrs:[ Vdom.Attr.class_ "card-actions" ]
        [ Ui.button
            ~classes:[ "ghost" ]
            ~on_click:(set_editing (not editing))
            (if editing then "Done" else "Edit")
        ; Ui.button
            ~classes:[ "danger"; "ghost" ]
            ~on_click:(inject (App_state.Action.Apply (Remove_member { id })))
            "Remove"
        ]
    ]
;;

(** The per-row state that {!Bonsai.assoc} creates and destroys with the row. *)
let component ~combatant ~is_active ~inject =
  let open Bonsai.Let_syntax in
  let%sub editing, set_editing = Bonsai.state (module Bool) ~default_model:false in
  let%sub amount, set_amount = Bonsai.state (module Int) ~default_model:1 in
  let%arr combatant = combatant
  and is_active = is_active
  and inject = inject
  and editing = editing
  and set_editing = set_editing
  and amount = amount
  and set_amount = set_amount in
  render ~inject ~is_active ~editing ~set_editing ~amount ~set_amount combatant
;;
