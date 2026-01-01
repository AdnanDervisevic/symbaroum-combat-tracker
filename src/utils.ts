export function uid(prefix: string) {
  return prefix + '_' + Math.random().toString(36).slice(2, 10)
}

export function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value))
}
