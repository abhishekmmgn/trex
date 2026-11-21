import { memo, forwardRef } from "react";

export function SaveBar({ onSave }) {
  return (
    <div className="actions">
      <button id="save" className="btn primary" onClick={onSave}>
        Save changes
      </button>
    </div>
  );
}

function Badge({ label }) {
  return <span id="badge">{label}</span>;
}
export const MemoBadge = memo(Badge);

function Field(props, ref) {
  return <input id="name" ref={ref} defaultValue="x" />;
}
export const RefField = forwardRef(Field);
