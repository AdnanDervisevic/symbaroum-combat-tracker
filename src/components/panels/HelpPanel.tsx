export function HelpPanel() {
  return (
    <section className="panel">
      <h2>Quick Help</h2>
      <ul>
        <li>Characters tab stores your standard PCs (localStorage).</li>
        <li>Encounter tab pulls PCs in, builds NPCs, and tracks initiative.</li>
        <li>Pain Threshold triggers auto-prone + warnings; amount input catches big hits.</li>
        <li>Edit per card when you need to tweak stats mid-session.</li>
      </ul>
      <p className="muted small">
        Rules reference: Symbaroum core book. Tracker simply records what you enter.
      </p>
    </section>
  );
}
