(** A JSON reader that accumulates errors instead of stopping at the first one. *)

open! Core

module Error : sig
  type t =
    { path : string (** JSONPath-ish, e.g. [$.encounter.members[0].name] *)
    ; message : string
    }
  [@@deriving compare, equal, sexp_of]

  val to_string_hum : t -> string
end

type 'a t

(** [return], [map], [apply], [both], [map2], [all], and the infix operators. *)
include Applicative.S with type 'a t := 'a t

(** For [let%map name = field "name" string and role = field "role" string in ...].

    Written out rather than included from [Applicative.Let_syntax] so that what
    is {i missing} is visible: there is no [bind], so there is no [let%bind], so
    a schema cannot branch on a decoded value and errors cannot help but
    accumulate. [Open_on_rhs] is empty on purpose -- decoders stay qualified at
    the call site, which keeps a long record decoder readable. *)
module Let_syntax : sig
  val return : 'a -> 'a t

  module Let_syntax : sig
    val return : 'a -> 'a t
    val map : 'a t -> f:('a -> 'b) -> 'b t
    val both : 'a t -> 'b t -> ('a * 'b) t

    module Open_on_rhs : sig end
  end
end

val run : 'a t -> Yojson.Safe.t -> ('a, Error.t list) Result.t

(** Unparseable JSON is one error at the root, not an exception. *)
val run_string : 'a t -> string -> ('a, Error.t list) Result.t

(** {1 Primitives} *)

(** The value as it stands, undecoded. For the rare field whose shape is the
    caller's business. *)
val json : Yojson.Safe.t t

(** Accepts a JSON number with no fractional part, whether it arrived as [10] or
    as [10.0]. JavaScript has one number type and [JSON.stringify] drops a
    trailing [.0], so the distinction is an artefact of the wire, not of the
    data. *)
val int : int t

val float : float t
val string : string t
val bool : bool t
val null : unit t

(** {1 Combinators} *)

(** Descends into an object field. A missing field is an error; use
    {!field_opt} or {!field_or} when it is allowed to be absent. *)
val field : string -> 'a t -> 'a t

(** [None] when the field is missing {i or} explicitly [null]. These are two
    spellings of the same thing in the data the React app writes -- [refId] is
    [null] when it was cleared and absent when it was never set -- and no code
    on either side has ever told them apart. *)
val field_opt : string -> 'a t -> 'a option t

val field_or : string -> 'a t -> default:'a -> 'a t
val list : 'a t -> 'a list t

(** [one_of expected ts] tries each in turn. [expected] is what the error says
    when none of them matched, because the alternatives' own errors describe
    shapes the value was never going to have. *)
val one_of : string -> 'a t list -> 'a t

(** Feeds a decoded value to a function that may reject it -- a smart
    constructor, usually. This is where [private] types are built, and it is the
    only way in. *)
val validate : 'a t -> f:('a -> ('b, string) Result.t) -> 'b t

(** {!validate} for the [Or_error.t] that most of this library's constructors
    return. *)
val validate_or_error : 'a t -> f:('a -> 'b Or_error.t) -> 'b t

val fail : string -> 'a t
