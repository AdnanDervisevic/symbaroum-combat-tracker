(** The magnitude of a damage or healing adjustment, [1 .. 999].

    The direction is not part of this type: it is the choice of command (Phase
    3). Zero is excluded, because [applyAdjustment]
    ({{:src/App.tsx} [App.tsx:398]}) clamps to [0 .. 999] and then returns early
    on zero -- so "adjust by nothing" is a state that code goes to the trouble
    of representing and then rejecting. *)

open! Core
include Bounded_int.S
