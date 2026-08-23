(** The verdict, computed off the render path.

    {1 Why it is not simply computed in the view}

    The exact solver runs a few tens of millions of floating-point operations for
    a realistic fight -- 9,801 states, ten combatants, forty rounds, fourteen
    outcomes apiece. That is fine once and unacceptable on every keystroke, so
    the analysis lives in state and the view only reads it.

    {1 The debounce, and why it is a poll rather than a timer}

    A tick once a second compares the {i signature} of the encounter against the
    signature the current answer was computed from, and recomputes when they
    differ. A burst of edits therefore costs one analysis rather than one per
    edit, and the gap is where the view can honestly say "working it out".

    A poll rather than a chain of timers because it needs no stale-result
    handling at all: there is only ever one analysis in flight, started and
    finished inside a single effect, so a late answer cannot overwrite a newer
    one. The plan called for a monotone request counter; polling makes it
    unnecessary, which is the better kind of simplification.

    {1 The signature}

    Built from exactly the fields the model reads -- and so, deliberately, {b not
    from names or notes}. Typing a note must not cost an analysis, and here it
    structurally cannot, because the note is not in the value being compared. *)

open! Core
open Bonsai_web
open Symbaroum

(* [Sexp] is already a Bonsai [Model] -- it round-trips and compares -- so the
   signature needs no type of its own. *)
let signature encounter =
  [%sexp
    (List.map (Encounter.members encounter) ~f:(fun (c : Combatant.t) ->
       ( Combatant.Allegiance.is_player c.allegiance
       , Initiative.to_int c.initiative
       , c.toughness
       , Defense.to_int c.defense
       , c.armor.text
       , Pain_threshold.to_int_option c.pain_threshold
       , c.prone
       , c.flanked
       , c.attributes
       , c.attack ))
     : (bool
       * int
       * Toughness.t
       * int
       * string
       * int option
       * bool
       * bool
       * Attributes.t
       * Attack_profile.t option)
         list)]
;;

module Cached = struct
  type t =
    { computed_from : Sexp.t
    ; analysis : Difficulty.t option
    }
  [@@deriving sexp, equal]

  (* Deliberately not a signature any encounter can have, so the first tick
     always computes. *)
  let nothing_yet = { computed_from = Sexp.Atom "<not computed>"; analysis = None }
end

let render ~working (cached : Cached.t) =
  match cached.analysis with
  | None when working ->
    Ui.muted ~small:true [ Ui.text "Difficulty: working it out\u{2026}" ]
  | None -> Vdom.Node.none
  | Some analysis ->
    let low, high = analysis.p_bounds in
    let bounds =
      (* The interval is only worth showing when it is wide enough to matter --
         which for the exact solver means essentially never, and for the sampler
         means always. *)
      if Float.(high - low < 0.005)
      then ""
      else
        sprintf
          " (%d\u{2013}%d%%)"
          (Float.iround_nearest_exn (low *. 100.))
          (Float.iround_nearest_exn (high *. 100.))
    in
    Vdom.Node.div
      (* Composed from the fields rather than from [Difficulty.to_string_hum],
         which already begins with the label -- so calling it after a "Difficulty:
         <label>" heading printed the label twice. That one is for the CLI. *)
      [ Vdom.Node.p
          ~attrs:[ Vdom.Attr.classes [ "muted"; "small" ] ]
          [ Vdom.Node.strong
              [ Ui.text
                  [%string "Difficulty: %{Difficulty.Label.to_string_hum analysis.label}"]
              ]
          ; Ui.text
              (String.concat
                 [ sprintf
                     " \u{2014} %d%% win%s, expect %.1f casualties"
                     (Float.iround_nearest_exn (analysis.p_party_wins *. 100.))
                     bounds
                     analysis.expected_party_casualties
                 ; (match
                      List.Assoc.find analysis.round_quantiles 0.5 ~equal:Float.equal
                    with
                    | None -> ""
                    | Some median -> sprintf ", median %d rounds" median)
                 ; (if working then " \u{2014} updating\u{2026}" else "")
                 ])
          ]
      ; Vdom.Node.p
          ~attrs:[ Vdom.Attr.classes [ "muted"; "small" ] ]
          [ Ui.text (Difficulty.Method.to_string_hum analysis.method_) ]
      ; (match analysis.caveats with
         | [] -> Vdom.Node.none
         | caveats ->
           Vdom.Node.ul
             ~attrs:[ Vdom.Attr.classes [ "muted"; "small" ] ]
             (List.map caveats ~f:(fun caveat ->
                Vdom.Node.li [ Ui.text (Caveat.to_string_hum caveat) ])))
      ]
;;

let component ~encounter =
  let open Bonsai.Let_syntax in
  let%sub signature =
    let%arr encounter = encounter in
    signature encounter
  in
  let%sub cached, set_cached =
    Bonsai.state (module Cached) ~default_model:Cached.nothing_yet
  in
  let%sub () =
    let%sub recompute =
      let%arr encounter = encounter
      and signature = signature
      and cached = cached
      and set_cached = set_cached in
      if Sexp.equal signature cached.computed_from
      then Effect.Ignore
      else
        Effect.bind (Effect.of_sync_fun Difficulty.analyze encounter) ~f:(fun analysis ->
          set_cached { computed_from = signature; analysis })
    in
    Bonsai.Clock.every
      ~when_to_start_next_effect:`Wait_period_after_previous_effect_finishes_blocking
      (Time_ns.Span.of_ms 400.)
      recompute
  in
  let%arr cached = cached
  and signature = signature in
  render ~working:(not (Sexp.equal signature cached.computed_from)) cached
;;
