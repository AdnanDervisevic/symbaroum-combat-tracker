import { useCallback, useEffect, useRef, useState } from 'react';
import { readStorage, versionedKey, writeStorage } from './storage';

type HistoryState<T> = {
  past: T[];
  present: T;
  future: T[];
  /**
   * The coalescing key of the entry currently on top. Another change carrying
   * the same key replaces `present` instead of pushing, so typing a sentence
   * into a note is one undo rather than fifty.
   */
  lastKey: string | null;
};

export type SetOptions = {
  /**
   * Identifies a run of edits to the same thing, e.g. `note:cmb_123`. Field
   * edits pass one; structural changes (add, remove, sort, next turn) do not.
   */
  coalesce?: string | null;
};

type UsePersistentHistoryReturn<T> = [
  T,
  (value: T | ((prev: T) => T), options?: SetOptions) => void,
  {
    undo: () => void;
    redo: () => void;
    canUndo: boolean;
    canRedo: boolean;
  }
];

const MAX_HISTORY = 50;

/**
 * The only writer of a history record, so the capacity trim cannot be forgotten
 * by one of three call sites again -- which is exactly what happened to `redo`.
 */
function pushed<T>(past: T[], present: T, future: T[], lastKey: string | null): HistoryState<T> {
  return { past: past.slice(-MAX_HISTORY), present, future, lastKey };
}

/**
 * Structural, not reference, equality.
 *
 * The old check was `newPresent === prev.present`, and every caller builds a
 * fresh object literal, so it never fired once. The state here is one encounter,
 * so stringifying it is cheap enough to do on each edit.
 */
function sameState<T>(a: T, b: T): boolean {
  if (a === b) return true;
  try {
    return JSON.stringify(a) === JSON.stringify(b);
  } catch {
    return false;
  }
}

export function usePersistentHistory<T>(
  key: string,
  initializer: () => T,
  migrateV1?: (raw: unknown) => T
): UsePersistentHistoryReturn<T> {
  const storageKey = versionedKey(key);

  const [history, setHistory] = useState<HistoryState<T>>(() => ({
    past: [],
    present: readStorage(key, initializer, migrateV1),
    future: [],
    lastKey: null,
  }));

  const isFirstRender = useRef(true);

  useEffect(() => {
    if (isFirstRender.current) {
      isFirstRender.current = false;
      return;
    }
    writeStorage(storageKey, history.present);
  }, [storageKey, history.present]);

  const setState = useCallback((value: T | ((prev: T) => T), options?: SetOptions) => {
    setHistory((prev) => {
      const newPresent = typeof value === 'function'
        ? (value as (prev: T) => T)(prev.present)
        : value;

      if (sameState(newPresent, prev.present)) return prev;

      const coalesce = options?.coalesce ?? null;
      if (coalesce !== null && coalesce === prev.lastKey) {
        // Same field, still being edited: replace rather than stack up.
        return pushed(prev.past, newPresent, [], coalesce);
      }
      return pushed([...prev.past, prev.present], newPresent, [], coalesce);
    });
  }, []);

  const undo = useCallback(() => {
    setHistory((prev) => {
      if (prev.past.length === 0) return prev;
      const newPast = [...prev.past];
      const newPresent = newPast.pop()!;
      return pushed(newPast, newPresent, [prev.present, ...prev.future], null);
    });
  }, []);

  const redo = useCallback(() => {
    setHistory((prev) => {
      if (prev.future.length === 0) return prev;
      const newFuture = [...prev.future];
      const newPresent = newFuture.shift()!;
      return pushed([...prev.past, prev.present], newPresent, newFuture, null);
    });
  }, []);

  return [
    history.present,
    setState,
    {
      undo,
      redo,
      canUndo: history.past.length > 0,
      canRedo: history.future.length > 0,
    },
  ];
}
