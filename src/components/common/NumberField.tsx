import { useEffect, useState } from 'react';
import type { FocusEvent } from 'react';
import { clamp } from '../../utils/core';

/**
 * A number input that holds the text you are typing rather than the number it
 * parses to.
 *
 * The original pattern was `value={n}` with `onChange={Number(e.target.value) || 0}`.
 * Selecting the contents and deleting them produces `""`, `Number("")` is `0`,
 * and the field snapped straight back to zero -- so a blank field was
 * unreachable and every half-typed value slammed the state to 0. Keeping the
 * draft here means the model only ever sees values that parse, and the field can
 * be empty while you think.
 *
 * These are `type="text"` with `inputMode="numeric"` rather than `type="number"`,
 * for two reasons that both matter at a table:
 *
 *   - A focused `type="number"` changes its value when the page is scrolled
 *     under the cursor. Scrolling past a combatant card should not quietly take
 *     four toughness off it.
 *   - `type="number"` does not support the selection API, so select-on-focus is
 *     unreliable there and cannot be tested at all.
 *
 * `inputMode="numeric"` still brings up the numeric keypad on iOS and Android,
 * which is the only thing `type="number"` was buying.
 */

type BaseProps = {
  min?: number;
  max?: number;
  className?: string;
  readOnly?: boolean;
  placeholder?: string;
  'aria-label'?: string;
};

const numericInput = {
  type: 'text' as const,
  inputMode: 'numeric' as const,
  pattern: '-?[0-9]*',
  autoComplete: 'off',
};

/** Focusing selects, so tapping a box showing `0` and typing gives what you typed. */
const selectAll = (e: FocusEvent<HTMLInputElement>) => {
  e.currentTarget.select();
};

type Props = BaseProps & {
  value: number;
  onCommit: (value: number) => void;
};

export function NumberField({ value, onCommit, min = 0, max = 999, readOnly, ...rest }: Props) {
  const [draft, setDraft] = useState(String(value));
  const [focused, setFocused] = useState(false);

  useEffect(() => {
    if (!focused) setDraft(String(value));
  }, [value, focused]);

  return (
    <input
      {...rest}
      {...numericInput}
      readOnly={readOnly}
      aria-readonly={readOnly}
      value={focused ? draft : String(value)}
      onFocus={(e) => {
        setFocused(true);
        setDraft(String(value));
        selectAll(e);
      }}
      onChange={(e) => {
        const text = e.target.value;
        setDraft(text);
        if (text.trim() === '') return;
        const n = Number(text);
        if (Number.isFinite(n)) onCommit(clamp(Math.round(n), min, max));
      }}
      onBlur={() => {
        setFocused(false);
        setDraft(String(value));
      }}
    />
  );
}

type OptionalProps = BaseProps & {
  value: number | null;
  onCommit: (value: number | null) => void;
};

/** The same, for a field where empty is a meaningful value rather than zero. */
export function OptionalNumberField({
  value,
  onCommit,
  min = 0,
  max = 999,
  readOnly,
  ...rest
}: OptionalProps) {
  const asText = (v: number | null) => (v === null ? '' : String(v));
  const [draft, setDraft] = useState(asText(value));
  const [focused, setFocused] = useState(false);

  useEffect(() => {
    if (!focused) setDraft(asText(value));
  }, [value, focused]);

  return (
    <input
      {...rest}
      {...numericInput}
      readOnly={readOnly}
      aria-readonly={readOnly}
      value={focused ? draft : asText(value)}
      onFocus={(e) => {
        setFocused(true);
        setDraft(asText(value));
        selectAll(e);
      }}
      onChange={(e) => {
        const text = e.target.value;
        setDraft(text);
        if (text.trim() === '') {
          onCommit(null);
          return;
        }
        const n = Number(text);
        if (Number.isFinite(n)) onCommit(clamp(Math.round(n), min, max));
      }}
      onBlur={() => {
        setFocused(false);
        setDraft(asText(value));
      }}
    />
  );
}
