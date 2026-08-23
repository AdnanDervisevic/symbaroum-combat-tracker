open! Core

(* Innermost segment first, so descending is a cons. Reversed once, when an
   error is built, which is the only time anyone looks. *)
module Path = struct
  type t = string list

  let empty = []
  let field t name = ("." ^ name) :: t
  let index t i = [%string "[%{i#Int}]"] :: t
  let to_string t = "$" ^ String.concat (List.rev t)
end

module Error = struct
  type t =
    { path : string
    ; message : string
    }
  [@@deriving compare, equal, sexp_of]

  let to_string_hum { path; message } = [%string "%{path}: %{message}"]
end

type 'a t = Path.t -> Yojson.Safe.t -> ('a, Error.t list) Result.t

let error path message = Error [ { Error.path = Path.to_string path; message } ]
let return a _ _ = Ok a
let fail message path _ = error path message
let map t ~f path json = Result.map (t path json) ~f

(* The whole point of the module. Both sides run regardless of what the other
   did, so their errors concatenate. A monadic bind could not do this: with
   nothing to feed the continuation it would have to stop here. *)
let apply f x path json =
  match f path json, x path json with
  | Ok f, Ok x -> Ok (f x)
  | Error left, Error right -> Error (left @ right)
  | Error e, Ok _ | Ok _, Error e -> Error e
;;

include Applicative.Make (struct
    type nonrec 'a t = 'a t

    let return = return
    let apply = apply
    let map = `Custom map
  end)

module Let_syntax = struct
  let return = return

  module Let_syntax = struct
    let return = return
    let map = map
    let both = both

    module Open_on_rhs = struct end
  end
end

let describe : Yojson.Safe.t -> string = function
  | `Null -> "null"
  | `Bool _ -> "a boolean"
  | `Int _ | `Intlit _ | `Float _ -> "a number"
  | `String _ -> "a string"
  | `List _ -> "an array"
  | `Assoc _ -> "an object"
;;

let expected what path json =
  error path [%string "expected %{what}, found %{describe json}"]
;;

let json _ json = Ok json

let int path json =
  match json with
  | `Int i -> Ok i
  (* JavaScript has one number type and [JSON.stringify] writes 10 for 10.0, so
     an integral float on the wire is an artefact of the format rather than a
     different value. A fractional one is not, and neither is [1e287]:
     [Float.to_int] raises on anything outside the int range, which is how the
     totality property found this. [iround_towards_zero] answers both questions
     at once, and the equality check is what rejects a fraction. *)
  | `Float f ->
    (match Float.iround_towards_zero f with
     | Some i when Float.equal (Float.of_int i) f -> Ok i
     | _ -> error path [%string "expected a whole number, found %{f#Float}"])
  | `Intlit s -> error path [%string "the number %{s} does not fit in an int"]
  | other -> expected "a whole number" path other
;;

let float path json =
  match json with
  | `Float f -> Ok f
  | `Int i -> Ok (Float.of_int i)
  | other -> expected "a number" path other
;;

let string path json =
  match json with
  | `String s -> Ok s
  | other -> expected "a string" path other
;;

let bool path json =
  match json with
  | `Bool b -> Ok b
  | other -> expected "a boolean" path other
;;

let null path json =
  match json with
  | `Null -> Ok ()
  | other -> expected "null" path other
;;

let field name decoder path json =
  match json with
  | `Assoc fields ->
    let path = Path.field path name in
    (match List.Assoc.find fields name ~equal:String.equal with
     | Some value -> decoder path value
     | None -> error path "the field is missing")
  | other -> expected [%string "an object with a %{name} field"] path other
;;

let field_opt name decoder path json =
  match json with
  | `Assoc fields ->
    (match List.Assoc.find fields name ~equal:String.equal with
     | None | Some `Null -> Ok None
     | Some value -> Result.map (decoder (Path.field path name) value) ~f:Option.some)
  | other -> expected [%string "an object with an optional %{name} field"] path other
;;

let field_or name decoder ~default =
  map (field_opt name decoder) ~f:(Option.value ~default)
;;

let list decoder path json =
  match json with
  | `List items ->
    List.mapi items ~f:(fun i item -> decoder (Path.index path i) item)
    |> Result.combine_errors
    |> Result.map_error ~f:List.concat
  | other -> expected "an array" path other
;;

let one_of what decoders path json =
  let rec first = function
    | [] -> expected what path json
    | decoder :: rest ->
      (match decoder path json with
       | Ok a -> Ok a
       | Error _ -> first rest)
  in
  first decoders
;;

let validate decoder ~f path json =
  match decoder path json with
  | Error _ as failed -> failed
  | Ok a ->
    (match f a with
     | Ok b -> Ok b
     | Error message -> error path message)
;;

let validate_or_error decoder ~f =
  validate decoder ~f:(fun a -> Result.map_error (f a) ~f:Core.Error.to_string_hum)
;;

let run t json = t Path.empty json

let run_string t s =
  match Yojson.Safe.from_string s with
  | json -> run t json
  | exception Yojson.Json_error message ->
    Error [ { Error.path = "$"; message = [%string "this is not JSON: %{message}"] } ]
;;
