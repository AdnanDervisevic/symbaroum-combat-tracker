(** The fight tab. *)

open! Core
open Bonsai_web
open Symbaroum

let render ~inject ~can_undo ~can_redo ~open_builder ~cards encounter =
  let round_line =
    match Encounter.current encounter with
    | None -> "No combatants yet."
    | Some current ->
      [%string
        "Round %{Round.to_int (Encounter.round encounter)#Int} \u{2014} Active: \
         %{Name.to_string current.name}"]
  in
  Vdom.Node.section
    ~attrs:[ Vdom.Attr.class_ "panel" ]
    [ Vdom.Node.div
        ~attrs:[ Vdom.Attr.class_ "panel-header" ]
        [ Vdom.Node.h2 [ Ui.text "Initiative Order" ]
        ; Vdom.Node.div
            ~attrs:[ Vdom.Attr.classes [ "panel-actions"; "wrap" ] ]
            [ Ui.button ~on_click:open_builder "Manage Combatants"
            ; Ui.button
                ~on_click:(inject (App_state.Action.Apply Sort_by_initiative))
                "Sort"
            ; Ui.button ~on_click:(inject (App_state.Action.Apply Prev_turn)) "Prev"
            ; Ui.button ~on_click:(inject (App_state.Action.Apply Next_turn)) "Next"
            ; Ui.button
                ~disabled:(not can_undo)
                ~title:"Undo"
                ~on_click:(inject App_state.Action.Undo)
                "\u{21B6}"
            ; Ui.button
                ~disabled:(not can_redo)
                ~title:"Redo"
                ~on_click:(inject App_state.Action.Redo)
                "\u{21B7}"
            ]
        ]
    ; Ui.muted ~small:true [ Ui.text round_line ]
    ; Vdom.Node.div
        ~attrs:[ Vdom.Attr.classes [ "cards"; "encounter-grid" ] ]
        (match Encounter.members encounter with
         | [] -> [ Ui.muted [ Ui.text "Add PCs or NPCs from the Manage dialog." ] ]
         | members ->
           List.map members ~f:(fun (c : Combatant.t) ->
             (* A row whose card is missing cannot happen -- [assoc] is keyed by
                the same map the order indexes -- but the panel says what it
                would mean rather than raising in a browser. *)
             Option.value
               (Map.find cards c.id)
               ~default:(Ui.muted [ Ui.text "(this combatant did not render)" ])))
    ]
;;

let component ~encounter ~inject ~can_undo ~can_redo ~open_builder =
  let open Bonsai.Let_syntax in
  let%sub members =
    let%arr encounter = encounter in
    Ids.Combatant_id.Map.of_alist_exn
      (List.map (Encounter.members encounter) ~f:(fun (c : Combatant.t) -> c.id, c))
  in
  let%sub current =
    let%arr encounter = encounter in
    Encounter.current_id encounter
  in
  let%sub cards =
    Bonsai.assoc
      (module Ids.Combatant_id)
      members
      ~f:(fun id combatant ->
        let%sub is_active =
          let%arr id = id
          and current = current in
          Option.value_map current ~default:false ~f:(Ids.Combatant_id.equal id)
        in
        Combatant_card.component ~combatant ~is_active ~inject)
  in
  let%arr encounter = encounter
  and inject = inject
  and can_undo = can_undo
  and can_redo = can_redo
  and open_builder = open_builder
  and cards = cards in
  render ~inject ~can_undo ~can_redo ~open_builder ~cards encounter
;;
