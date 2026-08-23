open! Core
module D = Json_decoder

type t =
  { world : World.t
  ; normalizations : Normalization.t list
  }

let of_wire_v2 wire =
  let world, normalizations = Domain_conv.to_domain wire in
  { world; normalizations }
;;

let root_error message = [ { D.Error.path = "$"; message } ]

let decode_json json =
  match D.run (D.field "version" D.int) json with
  | Error _ as failed -> failed
  | Ok declared ->
    if declared = Wire_v1.version
    then
      D.run Wire_v1.decoder json
      |> Result.map ~f:(fun v1 -> of_wire_v2 (Migrate.v1_to_v2 v1))
    else if declared = Wire_v2.version
    then D.run Wire_v2.decoder json |> Result.map ~f:of_wire_v2
    else
      Error
        [ { D.Error.path = "$.version"
          ; message =
              [%string
                "this file says version %{declared#Int}; this app reads versions \
                 %{Wire_v1.version#Int} and %{Wire_v2.version#Int}"]
          }
        ]
;;

let decode_string s =
  match Yojson.Safe.from_string s with
  | json -> decode_json json
  | exception Yojson.Json_error message ->
    Error (root_error [%string "this is not JSON: %{message}"])
;;

let to_json world = Wire_v2.yojson_of_t (Domain_conv.of_domain world)
let encode_string world = Yojson.Safe.pretty_to_string (to_json world)
let encode_string_compact world = Yojson.Safe.to_string (to_json world)

let of_local_storage_v1 ~find =
  let v1, errors = Wire_v1.Local_storage.load ~find in
  of_wire_v2 (Migrate.v1_to_v2 v1), errors
;;
