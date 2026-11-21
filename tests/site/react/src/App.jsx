import { SaveBar, MemoBadge, RefField } from "./SaveBar.jsx";

function SettingsForm() {
  return (
    <form onSubmit={(e) => e.preventDefault()}>
      <RefField />
      <MemoBadge label="new" />
      <SaveBar onSave={() => {}} />
    </form>
  );
}

export function SettingsPage() {
  return (
    <main id="app">
      <h1>Settings</h1>
      <SettingsForm />
    </main>
  );
}
