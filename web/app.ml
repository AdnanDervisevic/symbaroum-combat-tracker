(** The whole page.

    Everything that is not the state machine or a view lives here: the tab, the
    theme, whether the dialog is open, and the two edges that talk to the
    browser -- loading at startup and saving when the world changes. *)

open! Core
open Bonsai_web
open Symbaroum

module Tab = struct
  type t =
    | Characters
    | Encounter
    | Help
  [@@deriving compare, equal, enumerate, sexp]

  let to_string_hum = function
    | Characters -> "Characters"
    | Encounter -> "Encounter"
    | Help -> "Help"
  ;;
end

module Theme = struct
  type t =
    | Light
    | Dark
  [@@deriving compare, equal, sexp]

  let key = "sct.v1.theme"

  (* Read from the same key the React app writes, so a returning user keeps the
     theme they chose. Written back in the same spelling, so going back to the
     deployed app keeps it too. *)
  let load () =
    match Local_storage.find key with
    | Some raw when String.is_substring raw ~substring:"dark" -> Dark
    | Some _ | None -> Light
  ;;

  let to_attribute = function
    | Light -> "light"
    | Dark -> "dark"
  ;;

  let toggle = function
    | Light -> Dark
    | Dark -> Light
  ;;

  let icon = function
    | Light -> "\u{263E}"
    | Dark -> "\u{2600}"
  ;;
end

let export_filename () =
  (* [YYYY-MM-DD], without [core_unix] -- which must not appear in a JavaScript
     build -- and without an integer big enough to overflow one. The first
     version divided nanoseconds by 86_400_000_000_000, which js_of_ocaml
     truncated to 32 bits and warned about at build time. *)
  let days =
    Float.iround_down_exn
      (Time_ns.Span.to_day (Time_ns.to_span_since_epoch (Time_ns.now ())))
  in
  [%string "symbaroum-combat-%{Date.add_days Date.unix_epoch days#Date}.json"]
;;

let tabs ~tab ~set_tab ~theme ~set_theme =
  Vdom.Node.create
    "nav"
    ~attrs:[ Vdom.Attr.class_ "tabs" ]
    (List.map Tab.all ~f:(fun t ->
       Vdom.Node.button
         ~attrs:
           [ Vdom.Attr.classes
               (if Tab.equal t tab then [ "tab"; "active" ] else [ "tab" ])
           ; Vdom.Attr.on_click (fun _ -> set_tab t)
           ]
         [ Ui.text (Tab.to_string_hum t) ])
     @ [ Vdom.Node.button
           ~attrs:
             [ Vdom.Attr.class_ "theme-toggle"
             ; Vdom.Attr.title "Toggle theme"
             ; Vdom.Attr.on_click (fun _ -> set_theme (Theme.toggle theme))
             ]
           [ Ui.text (Theme.icon theme) ]
       ])
;;

let component =
  let open Bonsai.Let_syntax in
  let%sub state = App_state.component in
  let%sub tab, set_tab = Bonsai.state (module Tab) ~default_model:Tab.Characters in
  let%sub theme, set_theme = Bonsai.state (module Theme) ~default_model:(Theme.load ()) in
  let%sub builder_open, set_builder_open =
    Bonsai.state (module Bool) ~default_model:false
  in
  let%sub world =
    let%arr state = state in
    state.App_state.world
  in
  let%sub inject =
    let%arr state = state in
    state.App_state.inject
  in
  (* {1 The two edges}

     Loading happens once, when the page becomes active. Saving happens whenever
     the world changes -- and only when the world changes, so switching tabs or
     opening the dialog costs nothing. *)
  let%sub () =
    let%sub load =
      let%arr inject = inject in
      let world, normalizations, message = App_state.load () in
      let notice =
        match message, normalizations with
        | Some message, _ -> Some message
        | None, [] -> None
        | None, normalizations ->
          Some
            [%string
              "Loaded, with %{List.length normalizations#Int} correction(s) to your \
               saved data."]
      in
      Effect.Many
        [ inject (App_state.Action.Replace_world world)
        ; inject (App_state.Action.Note_storage_error notice)
        ]
    in
    Bonsai.Edge.lifecycle ~on_activate:load ()
  in
  (* Saving is polled rather than edge-triggered, for the same reason the
     difficulty readout is: a burst of keystrokes should cost one write, not one
     per character. Serialising and storing the whole world on every keystroke is
     what makes a web app feel broken. *)
  let%sub () =
    let%sub saved, set_saved =
      Bonsai.state (module App_state.World_model) ~default_model:World.empty
    in
    let%sub save =
      let%arr world = world
      and saved = saved
      and set_saved = set_saved
      and inject = inject in
      if World.equal world saved
      then Effect.Ignore
      else
        Effect.Many
          [ set_saved world
          ; (match
               Local_storage.set
                 App_state.storage_key
                 ~data:(Codec.encode_string_compact world)
             with
             | Ok () -> Effect.Ignore
             | Error error ->
               (* Not a [console.warn]. A GM whose fight has quietly stopped
                  saving deserves to be told. *)
               inject
                 (App_state.Action.Note_storage_error (Some (Error.to_string_hum error))))
          ]
    in
    Bonsai.Clock.every
      ~when_to_start_next_effect:`Wait_period_after_previous_effect_finishes_blocking
      (Time_ns.Span.of_sec 1.)
      save
  in
  let%sub () =
    let%sub write =
      let%arr set_theme = set_theme in
      ignore set_theme;
      fun theme ->
        Effect.Many
          [ Browser.set_theme_attribute (Theme.to_attribute theme)
          ; Effect.of_sync_fun
              (fun theme ->
                 ignore
                   (Local_storage.set
                      Theme.key
                      ~data:[%string "\"%{Theme.to_attribute theme}\""]
                    : unit Or_error.t))
              theme
          ]
    in
    Bonsai.Edge.on_change (module Theme) theme ~callback:write
  in
  let%sub characters =
    let%sub export =
      let%arr world = world in
      Browser.download
        ~filename:(export_filename ())
        ~contents:(Codec.encode_string world)
    in
    let%sub import =
      let%arr inject = inject in
      Browser.pick_text_file ~accept:".json" ~on_loaded:(fun text ->
        match Codec.decode_string text with
        | Ok { world; normalizations } ->
          Effect.Many
            [ inject (App_state.Action.Replace_world world)
            ; inject
                (App_state.Action.Note_storage_error
                   (if List.is_empty normalizations
                    then None
                    else
                      Some
                        [%string
                          "Imported, with %{List.length normalizations#Int} \
                           correction(s)."]))
            ]
        | Error errors ->
          inject
            (App_state.Action.Note_storage_error
               (Some
                  (String.concat
                     ~sep:" "
                     ("That file could not be read:"
                      :: List.map errors ~f:Json_decoder.Error.to_string_hum)))))
    in
    let%arr world = world
    and inject = inject
    and export = export
    and import = import in
    Characters_panel.render ~inject ~export ~import world.roster
  in
  let%sub encounter =
    let%sub encounter_value =
      let%arr world = world in
      world.World.encounter
    in
    let%sub can_undo =
      let%arr state = state in
      state.App_state.can_undo
    in
    let%sub can_redo =
      let%arr state = state in
      state.App_state.can_redo
    in
    let%sub open_builder =
      let%arr set_builder_open = set_builder_open in
      set_builder_open true
    in
    Encounter_panel.component
      ~encounter:encounter_value
      ~inject
      ~can_undo
      ~can_redo
      ~open_builder
  in
  let%sub modal =
    let%sub close =
      let%arr set_builder_open = set_builder_open in
      set_builder_open false
    in
    let%sub contents = Add_combatant_modal.component ~world ~inject ~close in
    let%arr contents = contents
    and builder_open = builder_open in
    if builder_open then contents else Vdom.Node.none
  in
  let%arr state = state
  and tab = tab
  and set_tab = set_tab
  and theme = theme
  and set_theme = set_theme
  and characters = characters
  and encounter = encounter
  and modal = modal in
  Vdom.Node.div
    ~attrs:[ Vdom.Attr.class_ "app-shell" ]
    [ Vdom.Node.main
        [ tabs ~tab ~set_tab ~theme ~set_theme
        ; (match tab with
           | Characters -> characters
           | Encounter -> encounter
           | Help -> Help_panel.render)
        ]
    ; modal
    ; (match state.App_state.storage_error with
       | None -> Vdom.Node.none
       | Some message ->
         Vdom.Node.div
           ~attrs:[ Vdom.Attr.classes [ "panel"; "storage-notice" ] ]
           [ Ui.muted ~small:true [ Ui.text message ] ])
    ; Toasts.render state.App_state.toasts
    ]
;;
