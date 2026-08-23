open! Core
open Bonsai_web
open Symbaroum

let storage_key = "sct.v2.app"
let persisted_past = 20

module World_model = struct
  type t = World.t

  let equal = World.equal
  let sexp_of_t world = Wire_v2.sexp_of_t (Domain_conv.of_domain world)
  let t_of_sexp sexp = fst (Domain_conv.to_domain (Wire_v2.t_of_sexp sexp))
end

module Toast = struct
  type t =
    { serial : int
    ; event : Event.t
    ; raised_at : Time_ns.Alternate_sexp.t
    }
  [@@deriving equal]

  let lifetime = Time_ns.Span.of_sec 6.

  (* [Event.t] has no [t_of_sexp] and should not grow one just for this, so the
     round trip goes through the string the UI shows anyway. Nothing reads a
     toast back; this exists because Bonsai's [Model] asks for it. *)
  let sexp_of_t { serial; event; raised_at } =
    [%sexp
      { serial : int
      ; message = (Event.to_string_hum event : string)
      ; raised_at : Time_ns.Alternate_sexp.t
      }]
  ;;

  let t_of_sexp (_ : Sexp.t) =
    failwith "Toasts are not restored from a sexp; they are transient by nature."
  ;;
end

module Model = struct
  type t =
    { history : World.t Undo_history.t
    ; next_id : int
    ; toasts : Toast.t list
    ; storage_error : string option
    }

  let initial =
    { history = Undo_history.create World.initial
    ; next_id = 1
    ; toasts = []
    ; storage_error = None
    }
  ;;

  let equal a b =
    Undo_history.equal World.equal a.history b.history
    && Int.equal a.next_id b.next_id
    && List.equal Toast.equal a.toasts b.toasts
    && Option.equal String.equal a.storage_error b.storage_error
  ;;

  (* Bonsai's [Model] wants a sexp round trip, and the domain types deliberately
     have no [t_of_sexp]: deriving one would construct records directly and
     reintroduce every illegal state, for the reasons set out at length in
     [json_decoder.mli]. So the model goes out through the wire types and comes
     back in through the smart constructors -- the same path a save file takes,
     and the same reason the wire types exist. *)
  module Serialized = struct
    type t =
      { present : Wire_v2.t
      ; past : Wire_v2.t list
      ; next_id : int
      ; storage_error : string option
      }
    [@@deriving sexp]
  end

  let sexp_of_t t =
    let present, past = Undo_history.to_persistable t.history ~keep_past:persisted_past in
    Serialized.sexp_of_t
      { present = Domain_conv.of_domain present
      ; past = List.map past ~f:Domain_conv.of_domain
      ; next_id = t.next_id
      ; storage_error = t.storage_error
      }
  ;;

  let t_of_sexp sexp =
    let { Serialized.present; past; next_id; storage_error } =
      Serialized.t_of_sexp sexp
    in
    let world wire = fst (Domain_conv.to_domain wire) in
    { history = Undo_history.of_persisted (world present) ~past:(List.map past ~f:world)
    ; next_id
    ; toasts = []
    ; storage_error
    }
  ;;
end

module Action = struct
  type t =
    | Apply of Symbaroum.Action.t
    | New_character
    | Send_to_fight of Ids.Character_id.t list
    | Add_npcs of Npc_draft.t
    | Clear_encounter
    | Undo
    | Redo
    | Replace_world of World.t
    | Expire_toasts
    | Note_storage_error of string option

  let sexp_of_t = function
    | Apply action -> [%sexp Apply (action : Symbaroum.Action.t)]
    | New_character -> [%sexp New_character]
    | Send_to_fight ids -> [%sexp Send_to_fight (ids : Ids.Character_id.t list)]
    | Add_npcs draft -> [%sexp Add_npcs (draft : Npc_draft.t)]
    | Clear_encounter -> [%sexp Clear_encounter]
    | Undo -> [%sexp Undo]
    | Redo -> [%sexp Redo]
    | Replace_world (_ : World.t) -> [%sexp Replace_world]
    | Expire_toasts -> [%sexp Expire_toasts]
    | Note_storage_error message -> [%sexp Note_storage_error (message : string option)]
  ;;

  (* Which UI actions are worth an undo entry, and which of those collapse into
     one. Delegated to the domain wherever there is a domain action to ask,
     because "is deleting a bestiary entry undoable" is a fact about the app and
     not about the button. *)
  let undoable = function
    | Apply action -> Symbaroum.Action.is_undoable action
    | New_character | Send_to_fight _ | Add_npcs _ | Clear_encounter -> true
    | Undo | Redo | Replace_world _ | Expire_toasts | Note_storage_error _ -> false
  ;;

  let coalesce_key = function
    | Apply action -> Symbaroum.Action.coalesce_key action
    | _ -> None
  ;;
end

type t =
  { world : World.t
  ; can_undo : bool
  ; can_redo : bool
  ; toasts : Toast.t list
  ; storage_error : string option
  ; inject : Action.t -> unit Effect.t
  }

(* Ids are minted from a counter in the model rather than from [Random], so the
   whole machine stays a function: the same actions from the same start produce
   the same world, which is what makes it testable at all. *)
let mint prefix n = [%string "%{prefix}_%{n#Int}"]

let load () =
  let from_v2 () =
    match Local_storage.find storage_key with
    | None -> None
    | Some raw ->
      (match Codec.decode_string raw with
       | Ok { world; normalizations } -> Some (world, normalizations, None)
       | Error errors ->
         Some
           ( World.initial
           , []
           , Some
               [%string
                 "Your saved data could not be read (%{List.length errors#Int} \
                  problem(s)); starting fresh."] ))
  in
  let from_v1 () =
    (* Anything written by the deployed React app. Read forever, written never. *)
    let has_v1 =
      List.exists
        [ Wire_v1.Local_storage.characters
        ; Wire_v1.Local_storage.encounter
        ; Wire_v1.Local_storage.bestiary
        ; Wire_v1.Local_storage.encounter_history
        ]
        ~f:(fun key -> Option.is_some (Local_storage.find key))
    in
    if not has_v1
    then None
    else (
      let { Codec.world; normalizations }, errors =
        Codec.of_local_storage_v1 ~find:Local_storage.find
      in
      Some
        ( world
        , normalizations
        , if List.is_empty errors
          then None
          else
            Some
              [%string
                "%{List.length errors#Int} of your older saved keys could not be read \
                 and were skipped."] ))
  in
  match from_v2 () with
  | Some loaded -> loaded
  | None ->
    (match from_v1 () with
     | Some loaded -> loaded
     | None -> World.initial, [], None)
;;

let apply_action
      ~inject:_
      ~schedule_event:_
      (now : Time_ns.t Bonsai.Computation_status.t)
      (model : Model.t)
      (action : Action.t)
  =
  let now =
    match now with
    | Active now -> now
    | Inactive -> Time_ns.epoch
  in
  let push model world =
    { model with
      Model.history =
        (if Action.undoable action
         then
           Undo_history.push
             model.Model.history
             world
             ~equal:World.equal
             ~key:(Action.coalesce_key action)
         else Undo_history.of_persisted world ~past:[])
    }
  in
  (* A non-undoable action still has to change the present. Rebuilding the
     history would throw the past away, so it is written through instead. *)
  let write_through (model : Model.t) world =
    if Action.undoable action
    then push model world
    else (
      let present, past =
        Undo_history.to_persistable model.history ~keep_past:Undo_history.default_capacity
      in
      ignore (present : World.t);
      { model with history = Undo_history.of_persisted world ~past })
  in
  let step model domain_action ~ids_used =
    let world, events =
      World.apply (Undo_history.present model.Model.history) domain_action
    in
    let model = write_through model world in
    let serial = model.next_id + ids_used in
    { model with
      next_id = serial + List.length events
    ; toasts =
        model.toasts
        @ List.mapi events ~f:(fun i event ->
          { Toast.serial = serial + i; event; raised_at = now })
    }
  in
  match action with
  | Expire_toasts ->
    { model with
      toasts =
        List.filter model.toasts ~f:(fun toast ->
          Time_ns.Span.( < ) (Time_ns.diff now toast.raised_at) Toast.lifetime)
    }
  | Note_storage_error message -> { model with storage_error = message }
  | Undo ->
    { model with
      history = Option.value (Undo_history.undo model.history) ~default:model.history
    }
  | Redo ->
    { model with
      history = Option.value (Undo_history.redo model.history) ~default:model.history
    }
  | Replace_world world ->
    { model with history = Undo_history.create world; toasts = model.toasts }
  | Apply domain_action -> step model domain_action ~ids_used:0
  | New_character ->
    let id = Ids.Character_id.of_string (mint "pc" model.next_id) in
    step { model with next_id = model.next_id + 1 } (Add_character { id }) ~ids_used:0
  | Send_to_fight character_ids ->
    let characters =
      List.mapi character_ids ~f:(fun i id ->
        id, Ids.Combatant_id.of_string (mint "cmb" (model.next_id + i)))
    in
    step
      { model with next_id = model.next_id + List.length characters }
      (Add_player_characters { characters })
      ~ids_used:0
  | Add_npcs draft ->
    let count = Npc_count.to_int draft.count in
    let ids =
      List.init count ~f:(fun i ->
        Ids.Combatant_id.of_string (mint "cmb" (model.next_id + i)))
    in
    let bestiary_id = Ids.Bestiary_id.of_string (mint "bst" (model.next_id + count)) in
    step
      { model with next_id = model.next_id + count + 1 }
      (Add_npcs { draft; ids; bestiary_id; at = now })
      ~ids_used:0
  | Clear_encounter ->
    let snapshot_id = Ids.Snapshot_id.of_string (mint "snp" model.next_id) in
    step
      { model with next_id = model.next_id + 1 }
      (Clear_encounter { snapshot_id; at = now })
      ~ids_used:0
;;

let component =
  let open Bonsai.Let_syntax in
  (* One-second granularity is plenty: the clock is read for archive labels and
     bestiary timestamps, and a state machine's input changing does not redraw
     anything that does not depend on it. *)
  let%sub now = Bonsai.Clock.approx_now ~tick_every:(Time_ns.Span.of_sec 1.) in
  let%sub model, inject =
    Bonsai.state_machine1
      (module Model)
      (module Action)
      ~default_model:Model.initial
      ~apply_action
      now
  in
  (* Expiry is a tick rather than a timer per toast, which is both simpler and
     the reason there is no [setTimeout] anywhere in this port. *)
  let%sub () =
    let%sub expire =
      let%arr inject = inject in
      inject Expire_toasts
    in
    Bonsai.Clock.every
      ~when_to_start_next_effect:`Every_multiple_of_period_non_blocking
      (Time_ns.Span.of_sec 1.)
      expire
  in
  let%arr model = model
  and inject = inject in
  { world = Undo_history.present model.history
  ; can_undo = Undo_history.can_undo model.history
  ; can_redo = Undo_history.can_redo model.history
  ; toasts = model.toasts
  ; storage_error = model.storage_error
  ; inject
  }
;;
