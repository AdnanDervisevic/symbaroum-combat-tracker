(** v1 forward into v2. Pure record shuffling: nothing here validates, clamps or
    reports, because {!Symbaroum.Domain_conv} does all of that once, for both
    versions, afterwards.

    Three of the moves are decisions rather than copies, and are worth reading.

    {1 One toughness becomes two}

    v1 stores a single [toughness]. For a roster character that number is the
    maximum; for a combatant in a fight it is what is left, and the maximum was
    never written down. So a wounded goblin at 4 comes back as 4 out of 4 --
    unless the number can be {i recovered}, and often it can: a player character
    still has its roster entry, and a typed NPC usually has a bestiary entry, and
    both of those record a full-health number. Where neither exists there is
    nothing to recover from, and the goblin looks unhurt. That loss is real and
    it is the reason v2 exists.

    {1 Defence flips from a modifier to a target}

    Every v1 [defense] is read as a modifier, uniformly -- see
    {!Symbaroum.Monster_preset} for why that reading was chosen and what it does
    for the two shipped characters whose value is [0]. v2 stores the absolute
    roll-under target, which is [10 - modifier].

    {1 The [pc_default_] prefix is read exactly once}

    {{:src/components/cards/CharacterCard.tsx} [CharacterCard.tsx:112]} asks
    whether an id starts with [pc_default_] every time it renders a card, which
    is a data property smuggled into a name and one that changes meaning the
    moment an import renumbers ids. Here the question is asked once, on the way
    out of the old format, and the answer is stored in a field. Reading it here
    is not the same mistake: at a migration boundary the prefix genuinely {i is}
    the data, because it is all the old format recorded. *)

open! Core

val v1_to_v2 : Wire_v1.t -> Wire_v2.t
