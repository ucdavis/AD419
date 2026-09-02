import type { OrgR } from '@/queries/orgr.ts';

export function OrgRSelect({
  ariaLabel,
  disabled = false,
  onChange,
  orgRs,
  value,
}: {
  ariaLabel: string;
  disabled?: boolean;
  onChange: (orgR: string | null) => void;
  orgRs: OrgR[];
  value: string | null;
}) {
  return (
    <select
      aria-label={ariaLabel}
      className={`select select-bordered select-sm ${value === null ? 'select-warning' : ''}`}
      disabled={disabled}
      onChange={(event) => onChange(event.target.value === '' ? null : event.target.value)}
      value={value ?? ''}
    >
      <option value="">Select OrgR</option>
      {orgRs.map((orgR) => (
        <option key={orgR.code} value={orgR.code}>
          {orgR.code}
        </option>
      ))}
    </select>
  );
}
