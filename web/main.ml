(** The entry point, and nothing else.

    Everything above this is a value: {!App.component} is a
    [Vdom.Node.t Bonsai.Computation.t], which is a description of a page and not
    a page. This line is where it becomes one, and it is the only line in the
    directory that does anything. *)

let () = Bonsai_web.Start.start ~bind_to_element_with_id:"app" App.component
