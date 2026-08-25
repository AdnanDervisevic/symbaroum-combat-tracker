(** The entry point, and nothing else. *)

let () = Bonsai_web.Start.start ~bind_to_element_with_id:"app" App.component
