import { useEffect, useState } from 'react';
import { clamp } from '../../utils';

/**
 * A number input that holds the text you are typing rather than the number it
 * parses to.
 *
 * The old pattern was `value={n}` with `onChange={Number(e.target.value) || 0}`.
 * Selecting the contents and deleting them produces `""`, `Number("")` is `0`,
 * and the field snapped straight back to zero -- so a blank field was
 * unreachable and every half-typed value slammed the state to 0. Keeping the
 * draft here means the model only sees values that actually parse, and the field
 * can be empty while you think.
 *
 * Focusing selects the contents, so tapping a box showing `0` and typing gives
 * you what you typed instead of `012`.
 */

type BaseProps = {
  min?: number;
  max?: number;
  className?: string;
  readOnly?: boolean;
  placeholder?: string;
  'aria-label'?: string;
};

type Props = BaseProps & {
  value: number;
  onCommit: (value: number) => void;
};

export function NumberField({
  value,
  onCommit,
  min = 0,
  max = 999,
  readOnly,
  ...rest
}: Props) {
  const [draft, setDraft] = useState(String(value));
  const [focused, setFocused] = useState(false);

  useEffect(() => {
    if (!focused) setDraft(String(value));
  }, [value, focused]);

  return (
    <input
      {...rest}
      type="number"
      inputMode="numeric"
      min={min}
      max={max}
      readOnly={readOnly}
      aria-readonly={readOnly}
      value={focused ? draft : String(value)}
      onFocus={(e) => {
        setFocused(true);
        setDraft(String(value));
        e.currentTarget.select();
      }}
      onChange={(e) => {
        const text = e.target.value;
        setDraft(text);
        if (text === '') return;
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
      type="number"
      inputMode="numeric"
      min={min}
      max={max}
      readOnly={readOnly}
      aria-readonly={readOnly}
      value={focused ? draft : asText(value)}
      onFocus={(e) => {
        setFocused(true);
        setDraft(asText(value));
        e.currentTarget.select();
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
