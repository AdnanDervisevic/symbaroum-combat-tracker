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

export type Character = {
  id: string
  name: string
  role: string
  initiative: number
  toughness: number
  defense: number
  armor: string
  painThreshold: number | null
  attributes?: CharacterAttributes | null
  note: string
}

export type CombatantSource = 'pc' | 'npc'

export type Combatant = {
  id: string
  source: CombatantSource
  refId?: string | null
  name: string
  initiative: number
  toughness: number
  defense: number
  armor: string
  painThreshold: number | null
  prone: boolean
  flanked: boolean
  attributes?: CharacterAttributes | null
  note?: string
}

export type EncounterState = {
  members: Combatant[]
  turnIndex: number
  round: number
}

export type ExportPayload = {
  version: number
  characters: Character[]
  encounter: EncounterState
}
