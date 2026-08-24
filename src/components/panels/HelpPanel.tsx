export function HelpPanel() {
  return (
    <section className="panel">
      <h2>Quick Help</h2>
      <ul>
        <li>Characters tab stores your standard PCs (localStorage).</li>
        <li>Encounter tab pulls PCs in, builds NPCs, and tracks initiative.</li>
        <li>
          Toughness is current out of maximum. Hurt and Heal move the current
          value and never take it past either end.
        </li>
        <li>
          Pain Threshold triggers auto-prone + warnings, against the damage that
          actually landed. Blank means the creature never goes prone; 0 means
          every hit does.
        </li>
        <li>
          Defense is the number you roll under. Monster presets print the
          modifier an attacker applies, and are converted when you load one.
        </li>
        <li>Edit per card when you need to tweak stats mid-session.</li>
      </ul>
      <p className="muted small">
        Rules reference: Symbaroum core book. This tracker records what you
        enter — it has no weapon, ability or mystical power data, and does not
        try to judge how a fight will go.
      </p>
    </section>
  );
}
