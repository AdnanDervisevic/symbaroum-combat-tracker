open! Core
open Bonsai_web
open Js_of_ocaml

let download ~filename ~contents =
  Effect.of_sync_fun
    (fun () ->
       let href =
         "data:application/json;charset=utf-8,"
         ^ Js.to_string (Js.encodeURIComponent (Js.string contents))
       in
       let anchor = Dom_html.createA Dom_html.document in
       anchor##setAttribute (Js.string "href") (Js.string href);
       anchor##setAttribute (Js.string "download") (Js.string filename);
       (* Firefox will not follow a click on an anchor that is not in the
          document, so it goes in and comes straight back out. *)
       Dom.appendChild Dom_html.document##.body anchor;
       anchor##click;
       Dom.removeChild Dom_html.document##.body anchor)
    ()
;;

let pick_text_file ~accept ~on_loaded =
  Effect.of_sync_fun
    (fun () ->
       let input = Dom_html.createInput ~_type:(Js.string "file") Dom_html.document in
       input##setAttribute (Js.string "accept") (Js.string accept);
       input##.onchange
       := Dom_html.handler (fun _ ->
            Option.iter
              (Js.Optdef.to_option input##.files)
              ~f:(fun files ->
                Option.iter
                  (Js.Opt.to_option (files##item 0))
                  ~f:(fun file ->
                    let reader = new%js File.fileReader in
                    reader##.onload
                    := Dom.handler (fun _ ->
                         (match
                            Js.Opt.to_option (File.CoerceTo.string reader##.result)
                          with
                          | None -> ()
                          | Some text ->
                            (* Outside Bonsai's own dispatch, so the effect has to be
                           handed to the scheduler explicitly. *)
                            Effect.Expert.handle_non_dom_event_exn
                              (on_loaded (Js.to_string text)));
                         Js._true);
                    reader##readAsText file));
            Js._true);
       input##click)
    ()
;;

let set_theme_attribute theme =
  Effect.of_sync_fun
    (fun theme ->
       Dom_html.document##.documentElement##setAttribute
         (Js.string "data-theme")
         (Js.string theme))
    theme
;;
