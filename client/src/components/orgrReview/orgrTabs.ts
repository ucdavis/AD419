export type OrgRTabId =
  | 'orgrs'
  | 'financial-departments'
  | 'nifa-departments'
  | 'projects';

export interface OrgRTab {
  id: OrgRTabId;
  label: string;
  note: string | null;
}

export const ORGR_TABS: OrgRTab[] = [
  {
    id: 'orgrs',
    label: 'OrgR List',
    note: 'OrgRs group expenses and projects onto department screens. Add OrgRs and edit their descriptions here. To change a code, add the new one, reassign its mappings, and delete the old one.',
  },
  {
    id: 'financial-departments',
    label: 'Financial Departments',
    note: 'Every included financial department needs an OrgR. UCPath transactions with title code 1010 are always assigned ADNO.',
  },
  {
    id: 'nifa-departments',
    label: 'NIFA Departments',
    note: 'The department segment of the NIFA project number (characters 6 to 8) sets each project’s default OrgR.',
  },
  {
    id: 'projects',
    label: 'Project OrgRs',
    note: 'Add a project to another OrgR when its PI holds appointments in more than one department.',
  },
];

export function unmappedCount(rows: { orgR: string | null }[]): number {
  return rows.filter((row) => row.orgR === null).length;
}

export function allMapped(
  departments: { orgR: string | null }[],
  nifaDepartments: { orgR: string | null }[]
): boolean {
  return unmappedCount(departments) === 0 && unmappedCount(nifaDepartments) === 0;
}

// Rows ordered with unmapped (null orgR) rows first, otherwise by code.
export function unmappedFirst<T extends { orgR: string | null }>(
  rows: T[],
  codeOf: (row: T) => string
): T[] {
  return [...rows].sort(
    (a, b) =>
      (a.orgR === null ? 0 : 1) - (b.orgR === null ? 0 : 1) ||
      codeOf(a).localeCompare(codeOf(b))
  );
}
