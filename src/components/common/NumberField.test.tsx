// @vitest-environment jsdom
import { useState } from 'react'
import { describe, expect, it, afterEach } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { NumberField, OptionalNumberField } from './NumberField'

afterEach(cleanup)

/**
 * The complaint that started this: the fields were painful to type into.
 *
 * `value={n}` with `onChange={Number(e.target.value) || 0}` means clearing the
 * contents produces `""`, `Number("")` is `0`, and the field snaps straight back
 * to zero — so a blank field was unreachable and every half-typed value slammed
 * the model to 0.
 */

function Harness({ initial = 10, min = 0, max = 999 }) {
  const [value, setValue] = useState(initial)
  return (
    <>
      <NumberField value={value} onCommit={setValue} min={min} max={max} aria-label="field" />
      <output>{value}</output>
    </>
  )
}

function OptionalHarness({ initial = 5 as number | null }) {
  const [value, setValue] = useState<number | null>(initial)
  return (
    <>
      <OptionalNumberField value={value} onCommit={setValue} aria-label="field" />
      <output>{value === null ? 'null' : value}</output>
    </>
  )
}

const field = () => screen.getByLabelText('field') as HTMLInputElement
const model = () => screen.getByText((_, el) => el?.tagName === 'OUTPUT').textContent

describe('NumberField', () => {
  it('can be emptied while you think', () => {
    render(<Harness />)
    fireEvent.focus(field())
    fireEvent.change(field(), { target: { value: '' } })
    expect(field().value).toBe('')
    // And the model keeps the last value it was given rather than becoming 0.
    expect(model()).toBe('10')
  })

  it('commits what you type', () => {
    render(<Harness />)
    fireEvent.focus(field())
    fireEvent.change(field(), { target: { value: '12' } })
    expect(model()).toBe('12')
  })

  it('puts the old value back if you leave it blank', () => {
    render(<Harness />)
    fireEvent.focus(field())
    fireEvent.change(field(), { target: { value: '' } })
    fireEvent.blur(field())
    expect(field().value).toBe('10')
    expect(model()).toBe('10')
  })

  it('clamps to the bounds it was given', () => {
    render(<Harness min={1} max={20} />)
    fireEvent.focus(field())
    fireEvent.change(field(), { target: { value: '99' } })
    expect(model()).toBe('20')
    fireEvent.change(field(), { target: { value: '-5' } })
    expect(model()).toBe('1')
  })

  it('follows the model when it changes from elsewhere', () => {
    const { rerender } = render(<NumberField value={4} onCommit={() => {}} aria-label="field" />)
    rerender(<NumberField value={9} onCommit={() => {}} aria-label="field" />)
    expect(field().value).toBe('9')
  })

  it('selects its contents on focus, so typing replaces rather than appends', () => {
    render(<Harness />)
    fireEvent.focus(field())
    expect(field().selectionStart).toBe(0)
    expect(field().selectionEnd).toBe(String(10).length)
  })
})

describe('OptionalNumberField', () => {
  it('reads empty as a real value rather than as zero', () => {
    render(<OptionalHarness />)
    fireEvent.focus(field())
    fireEvent.change(field(), { target: { value: '' } })
    expect(model()).toBe('null')
  })

  it('shows nothing at all for null', () => {
    render(<OptionalHarness initial={null} />)
    expect(field().value).toBe('')
  })

  it('still takes a number', () => {
    render(<OptionalHarness initial={null} />)
    fireEvent.focus(field())
    fireEvent.change(field(), { target: { value: '7' } })
    expect(model()).toBe('7')
  })
})
