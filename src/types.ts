export type CharacterAttributes = {
  acc?: number | null
  cun?: number | null
  dis?: number | null
  per?: number | null
  qui?: number | null
  res?: number | null
  str?: number | null
  vig?: number | null
}

export type AttributeKey = keyof CharacterAttributes

/**
 * Current and maximum toughness.
 *
 * These used to be one number, so a wounded combatant's maximum was simply not
 * recorded and nothing could show "6 / 10". Keep them together and clamp in one
 * place: see `src/utils/toughness.ts`.
 */
export type Toughness = {
  current: number
  max: number
}

export type Character = {
  id: string
  name: string
  role: string
  initiative: number
  /** The maximum. A roster character is not in a fight, so it is all they have. */
  toughness: number
  /**
   * The roll-under target on the character's sheet — the number the GM rolls
   * under. Monster statblocks print the *modifier* an attacker applies instead;
   * those are converted on the way in. See `loadPresetIntoDraft`.
   */
  defense: number
  armor: string
  painThreshold: number | null
  attributes?: CharacterAttributes | null
  note: string
  /**
   * Shipped with the app rather than created by the user. This replaces
   * `id.startsWith('pc_default_')`, which smuggled a data property into an
   * identifier and asked the question on every render.
   */
  isBuiltin?: boolean
}

export type CombatantSource = 'pc' | 'npc'

type CombatantCommon = {
  id: string
  name: string
  initiative: number
  toughness: Toughness
  defense: number
  armor: string
  painThreshold: number | null
  prone: boolean
  flanked: boolean
  attributes?: CharacterAttributes | null
  note?: string
}

/**
 * A combatant is either a player character with a roster id, or an NPC that may
 * name a monster type. Writing it as a union rather than three loosely coupled
 * optional fields makes `{ source: 'npc', refId: 'pc_x' }` a compile error
 * instead of something a runtime guard has to catch.
 */
export type Combatant = CombatantCommon &
  (
    | { source: 'pc'; refId: string; monsterType?: undefined }
    | { source: 'npc'; refId?: undefined; monsterType?: string }
  )

export type BestiaryEntry = {
  id: string
  monsterType: string
  initiative: number
  /** A template, so this is the maximum a fresh one of these starts at. */
  toughness: number
  defense: number
  armor: string
  painThreshold: number | null
  note: string
  /** Carried so that reloading a saved monster restores its statblock too. */
  attributes?: CharacterAttributes | null
  updatedAt: number
}

export type EncounterState = {
  members: Combatant[]
  turnIndex: number
  round: number
  /**
   * Highest number handed out per monster type, ever — not a count of the ones
   * currently alive. Counting live members meant that removing Goblin 2 and
   * adding another produced a second Goblin 3.
   */
  nameCounter: Record<string, number>
}

export type ExportPayload = {
  version: number
  characters: Character[]
  encounter: EncounterState
  bestiary?: BestiaryEntry[]
}

/**
 * A change to one field of one combatant.
 *
 * This replaces `Partial<Combatant>`, whose shallow merge could set *any* field
 * to *any* value — including `source`, and including a negative toughness. The
 * `field` tag is also what gives undo its coalescing key, so a run of edits to
 * one note collapses into a single entry.
 */
export type MemberPatch =
  | { field: 'name'; value: string }
  | { field: 'initiative'; value: number }
  | { field: 'toughnessCurrent'; value: number }
  | { field: 'toughnessMax'; value: number }
  | { field: 'defense'; value: number }
  | { field: 'armor'; value: string }
  | { field: 'painThreshold'; value: number | null }
  | { field: 'prone'; value: boolean }
  | { field: 'flanked'; value: boolean }
  | { field: 'note'; value: string }

export type EncounterHistoryEntry = {
  id: string
  timestamp: number
  label: string
  encounter: EncounterState
}
