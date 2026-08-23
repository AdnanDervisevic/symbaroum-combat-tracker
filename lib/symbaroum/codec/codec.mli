(** The whole pipeline, in one place.

    {v
      raw string -> Yojson.Safe.from_string -> version dispatch
        -> Wire_v1.decoder | Wire_v2.decoder   (total records, no invariants)
        -> Migrate.v1_to_v2                    (pure record shuffling)
        -> Domain_conv.to_domain               (smart constructors; the ONLY place)
             : World.t * Normalization.t list
    v} *)

open! Core

type t =
  { world : World.t
  ; normalizations : Normalization.t list
    (** Everything that was repaired on the way in. Empty for a file this app
          wrote. *)
  }

val decode_json : Yojson.Safe.t -> (t, Json_decoder.Error.t list) Result.t

(** Text that is not JSON is one error at the root rather than an exception. *)
val decode_string : string -> (t, Json_decoder.Error.t list) Result.t

val to_json : World.t -> Yojson.Safe.t

(** What the export button writes. Indented, because a save a GM might open in an
    editor is worth two kilobytes of whitespace. *)
val encode_string : World.t -> string

(** Compact, for [localStorage], where the whitespace is a real cost against the
    quota. *)
val encode_string_compact : World.t -> string

(** Reads the five [sct.v1.*] keys the deployed app writes and migrates them, for
    the browser that has data but has never seen this port. [find] is
    [localStorage.getItem].

    A key that is present but unreadable is reported and skipped rather than
    failing the load, so the returned errors are advisory -- there is always a
    world. *)
val of_local_storage_v1 : find:(string -> string option) -> t * Json_decoder.Error.t list
