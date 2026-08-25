// @vitest-environment jsdom
import { afterEach, describe, expect, it, vi } from 'vitest'
import { onStorageError, readStorage, versionedKey, writeStorage } from './storage'

/**
 * The layer that touches somebody's actual saved session. Two properties matter
 * more than anything else here: version 1 data is read, and version 1 data is
 * *kept*.
 */

afterEach(() => {
  localStorage.clear()
  onStorageError(null)
  vi.restoreAllMocks()
})

const fallback = () => ({ from: 'fallback' })

describe('key naming', () => {
  it('versions the app keys and leaves anything else alone', () => {
    expect(versionedKey('sct.encounter')).toBe('sct.v2.encounter')
    expect(versionedKey('sct.encounter', 1)).toBe('sct.v1.encounter')
    expect(versionedKey('somebody-elses-key')).toBe('somebody-elses-key')
  })
})

describe('reading', () => {
  it('prefers the current version', () => {
    localStorage.setItem('sct.v2.thing', JSON.stringify({ from: 'v2' }))
    localStorage.setItem('sct.v1.thing', JSON.stringify({ from: 'v1' }))
    expect(readStorage('sct.thing', fallback, () => ({ from: 'migrated' }))).toEqual({ from: 'v2' })
  })

  it('migrates version 1 when there is no version 2', () => {
    localStorage.setItem('sct.v1.thing', JSON.stringify({ from: 'v1' }))
    const value = readStorage('sct.thing', fallback, (raw) => ({
      from: 'migrated from ' + (raw as { from: string }).from,
    }))
    expect(value).toEqual({ from: 'migrated from v1' })
  })

  it('keeps the version 1 key as a backup rather than deleting it', () => {
    // This runs against data somebody is using at a table. A migration that
    // removes the only copy of the old shape has no way back.
    localStorage.setItem('sct.v1.thing', JSON.stringify({ from: 'v1' }))
    readStorage('sct.thing', fallback, (raw) => raw as { from: string })
    expect(localStorage.getItem('sct.v1.thing')).toBe(JSON.stringify({ from: 'v1' }))
  })

  it('writes what it migrated back out, so the work happens once', () => {
    localStorage.setItem('sct.v1.thing', JSON.stringify({ from: 'v1' }))
    readStorage('sct.thing', fallback, () => ({ from: 'migrated' }))
    expect(JSON.parse(localStorage.getItem('sct.v2.thing') as string)).toEqual({ from: 'migrated' })
  })

  it('still reads the unversioned keys that predate versioning', () => {
    localStorage.setItem('sct.thing', JSON.stringify({ from: 'ancient' }))
    expect(readStorage('sct.thing', fallback, (raw) => raw as { from: string })).toEqual({
      from: 'ancient',
    })
  })

  it('falls back rather than throwing on unreadable data', () => {
    // The warning is the point, but it does not need to be in the test output.
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {})
    localStorage.setItem('sct.v2.thing', '{ not json')
    expect(readStorage('sct.thing', fallback)).toEqual({ from: 'fallback' })
    expect(warn).toHaveBeenCalled()
  })

  it('falls back when there is old data but no migration for it', () => {
    localStorage.setItem('sct.v1.thing', JSON.stringify({ from: 'v1' }))
    expect(readStorage('sct.thing', fallback)).toEqual({ from: 'fallback' })
  })
})

describe('writing', () => {
  it('round-trips', () => {
    expect(writeStorage('k', { a: 1 })).toBe(true)
    expect(JSON.parse(localStorage.getItem('k') as string)).toEqual({ a: 1 })
  })

  it('reports a failure instead of swallowing it', () => {
    // A quota error used to be a console.warn, so a full localStorage meant the
    // session quietly stopped saving and you found out by reloading.
    vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
      throw new DOMException('quota', 'QuotaExceededError')
    })
    const seen: string[] = []
    onStorageError((key) => seen.push(key))

    expect(writeStorage('sct.v2.thing', { a: 1 })).toBe(false)
    expect(seen).toEqual(['sct.v2.thing'])
  })

  it('falls back to the console when nobody is listening', () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {})
    vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
      throw new Error('nope')
    })
    expect(writeStorage('k', 1)).toBe(false)
    expect(warn).toHaveBeenCalled()
  })
})
