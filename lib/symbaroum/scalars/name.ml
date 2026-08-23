open! Core

include
  String_id.Make
    (struct
      let module_name = "Symbaroum.Name"
    end)
    ()

let numbered ~base n = of_string [%string "%{base#Monster_type} %{n#Int}"]
