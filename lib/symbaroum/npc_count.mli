(** How many copies of an NPC preset to add at once.

    [NPC_COUNT_MIN] and [NPC_COUNT_MAX] in
    {{:src/utils/npcConstants.ts} [npcConstants.ts]} are enforced by the number
    input and nowhere else, so the handler will add zero or a thousand goblins
    if the value arrives by any other route. *)

open! Core
include Bounded_int.S
