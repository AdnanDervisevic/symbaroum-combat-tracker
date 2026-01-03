import { useCallback, useEffect, useRef, useState } from 'react';

type HistoryState<T> = {
  past: T[];
  present: T;
  future: T[];
};

type UsePersistentHistoryReturn<T> = [
  T,
  (value: T | ((prev: T) => T)) => void,
  {
    undo: () => void;
    redo: () => void;
    canUndo: boolean;
    canRedo: boolean;
  }
];

const MAX_HISTORY = 50;
const STORAGE_VERSION = 1;

function getVersionedKey(key: string): string {
  if (key.startsWith('sct.')) {
    return `sct.v${STORAGE_VERSION}.${key.slice(4)}`;
  }
  return key;
}

function loadFromStorage<T>(key: string, fallback: () => T): T {
  if (typeof window === 'undefined') return fallback();
  const versionedKey = getVersionedKey(key);
  try {
    const raw = window.localStorage.getItem(versionedKey);
    if (raw) return JSON.parse(raw) as T;
    // Try old key migration
    const oldRaw = window.localStorage.getItem(key);
    if (oldRaw) {
      const data = JSON.parse(oldRaw) as T;
      window.localStorage.setItem(versionedKey, oldRaw);
      window.localStorage.removeItem(key);
      return data;
    }
    return fallback();
  } catch {
    return fallback();
  }
}

export function usePersistentHistory<T>(
  key: string,
  initializer: () => T
): UsePersistentHistoryReturn<T> {
  const versionedKey = getVersionedKey(key);

  const [history, setHistory] = useState<HistoryState<T>>(() => ({
    past: [],
    present: loadFromStorage(key, initializer),
    future: [],
  }));

  const isFirstRender = useRef(true);

  // Save to localStorage when present changes
  useEffect(() => {
    if (isFirstRender.current) {
      isFirstRender.current = false;
      return;
    }
    try {
      window.localStorage.setItem(versionedKey, JSON.stringify(history.present));
    } catch (err) {
      console.warn('Failed to save to localStorage', err);
    }
  }, [versionedKey, history.present]);

  const setState = useCallback((value: T | ((prev: T) => T)) => {
    setHistory((prev) => {
      const newPresent = typeof value === 'function'
        ? (value as (prev: T) => T)(prev.present)
        : value;

      if (newPresent === prev.present) return prev;

      return {
        past: [...prev.past, prev.present].slice(-MAX_HISTORY),
        present: newPresent,
        future: [],
      };
    });
  }, []);

  const undo = useCallback(() => {
    setHistory((prev) => {
      if (prev.past.length === 0) return prev;
      const newPast = [...prev.past];
      const newPresent = newPast.pop()!;
      return {
        past: newPast,
        present: newPresent,
        future: [prev.present, ...prev.future],
      };
    });
  }, []);

  const redo = useCallback(() => {
    setHistory((prev) => {
      if (prev.future.length === 0) return prev;
      const newFuture = [...prev.future];
      const newPresent = newFuture.shift()!;
      return {
        past: [...prev.past, prev.present],
        present: newPresent,
        future: newFuture,
      };
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
