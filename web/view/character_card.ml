(** One roster entry. *)

open! Core
open Bonsai_web
open Symbaroum

let patch inject id p =
  inject (App_state.Action.Apply (Update_character { id; patch = p }))
;;

let optional_patch inject id p =
  match p with
  | Some p -> patch inject id p
  | None -> Effect.Ignore
;;

let stat ~label ~value ~on_change =
  Ui.labelled ~label (Ui.number_input ~value ~on_change ())
;;

let render ~inject (character : Character.t) =
  let id = character.id in
  let set p = patch inject id p in
  let try_set p = optional_patch inject id p in
  Vdom.Node.div
    ~attrs:[ Vdom.Attr.classes [ "card"; "character-card" ] ]
    [ Vdom.Node.div
        ~attrs:[ Vdom.Attr.classes [ "card-line"; "dual" ] ]
        [ Ui.text_input
            ~classes:[ "name" ]
            ~placeholder:"Name"
            ~value:(Name.to_string character.name)
            ~on_change:(fun typed ->
              match Option.try_with (fun () -> Name.of_string typed) with
              | Some name -> set (Set_name name)
              | None -> Effect.Ignore)
            ()
        ; Ui.text_input
            ~classes:[ "role" ]
            ~placeholder:"Role"
            ~value:character.role
            ~on_change:(fun role -> set (Set_role role))
            ()
        ]
    ; Vdom.Node.div
        ~attrs:[ Vdom.Attr.classes [ "grid"; "stats" ] ]
        [ stat
            ~label:"Initiative"
            ~value:(Int.to_string (Initiative.to_int character.initiative))
            ~on_change:(fun n ->
              try_set
                (Option.bind n ~f:(fun n ->
                   Ui.guarded
                     ~of_int:Initiative.of_int
                     ~f:(fun i -> Character_patch.Set_initiative i)
                     n)))
        ; stat
            ~label:"Toughness"
            ~value:(Int.to_string character.toughness.max)
            ~on_change:(fun n ->
              try_set (Option.map n ~f:(fun n -> Character_patch.Set_max_toughness n)))
        ; stat
            ~label:"Defense"
            ~value:(Int.to_string (Defense.to_int character.defense))
            ~on_change:(fun n ->
              try_set
                (Option.bind n ~f:(fun n ->
                   Ui.guarded
                     ~of_int:Defense.of_target
                     ~f:(fun d -> Character_patch.Set_defense d)
                     n)))
        ; Ui.labelled
            ~label:"Armor"
            (Ui.text_input
               ~value:character.armor.text
               ~on_change:(fun text -> set (Set_armor (Armor.parse text)))
               ())
        ; stat
            ~label:"Pain Threshold"
            ~value:
              (Option.value_map
                 (Pain_threshold.to_int_option character.pain_threshold)
                 ~default:""
                 ~f:Int.to_string)
            ~on_change:(fun n ->
              set (Set_pain_threshold (Pain_threshold.of_int_option n)))
        ]
    ; Vdom.Node.details
        ~attrs:[ Vdom.Attr.class_ "attributes-editor" ]
        [ Vdom.Node.summary [ Ui.text "Attributes (optional)" ]
        ; Vdom.Node.div
            ~attrs:[ Vdom.Attr.class_ "attributes-grid" ]
            (List.map Attribute.all ~f:(fun attribute ->
               Ui.labelled
                 ~label:(Attribute.to_label attribute)
                 (Ui.number_input
                    ~value:
                      (Option.value_map
                         (Attributes.find character.attributes attribute)
                         ~default:""
                         ~f:(fun v -> Int.to_string (Attribute_value.to_int v)))
                    ~on_change:(fun n ->
                      match n with
                      | None -> set (Set_attribute (attribute, None))
                      | Some n ->
                        (match Attribute_value.of_int n with
                         | Ok v -> set (Set_attribute (attribute, Some v))
                         | Error _ -> Effect.Ignore))
                    ())))
        ]
    ; Ui.textarea
        ~placeholder:"Notes"
        ~value:character.note
        ~on_change:(fun note -> set (Set_note note))
        ()
    ; (if character.is_builtin
       then Vdom.Node.none
       else
         Vdom.Node.div
           ~attrs:[ Vdom.Attr.class_ "card-actions" ]
           [ Ui.button
               ~classes:[ "danger"; "ghost" ]
               ~on_click:(inject (App_state.Action.Apply (Delete_character { id })))
               "Delete"
           ])
    ]
;;
