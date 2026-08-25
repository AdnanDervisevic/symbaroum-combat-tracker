import { useCallback, useEffect, useRef, useState } from 'react';
import { readStorage, versionedKey, writeStorage } from './storage';
import * as History from './history';
import type { HistoryState } from './history';

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

/**
 * A value with undo/redo, persisted.
 *
 * Only `present` is written to storage — the stack is a session thing. The
 * stack logic itself lives in `./history`, where it can be tested without a
 * renderer.
 */
export function usePersistentHistory<T>(
  key: string,
  initializer: () => T,
  migrateV1?: (raw: unknown) => T
): UsePersistentHistoryReturn<T> {
  const storageKey = versionedKey(key);

  const [history, setHistory] = useState<HistoryState<T>>(() =>
    History.initialHistory(readStorage(key, initializer, migrateV1))
  );

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
      const next =
        typeof value === 'function' ? (value as (prev: T) => T)(prev.present) : value;
      return History.record(prev, next, options?.coalesce ?? null);
    });
  }, []);

  const undo = useCallback(() => setHistory(History.undo), []);
  const redo = useCallback(() => setHistory(History.redo), []);

  return [
    history.present,
    setState,
    {
      undo,
      redo,
      canUndo: History.canUndo(history),
      canRedo: History.canRedo(history),
    },
  ];
}
