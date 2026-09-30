import type { AutoAssociationBuild } from '@/queries/autoAssociations.ts';

export type AutoAssociationsTabId =
  | 'rule-204'
  | 'rule-20x'
  | 'rule-220'
  | 'excluded'
  | 'fte'
  | 'totals'
  | 'job-codes';

export interface AutoAssociationsTab {
  id: AutoAssociationsTabId;
  label: string;
  note: string;
}

export const AUTO_ASSOCIATIONS_TABS: AutoAssociationsTab[] = [
  {
    id: 'rule-204',
    label: '204',
    note: 'Expenses on a 204 AE project go to that project. The remainder shows 204 expenses no rule could place, including misclassified rows.',
  },
  {
    id: 'rule-20x',
    label: '201 / 202 / 205',
    note: 'Expenses on Hatch, Multi-State and Animal Health funds follow the PI and are prorated equally across the PI’s projects of the same SFN.',
  },
  {
    id: 'rule-220',
    label: '220',
    note: 'State Appropriations (13U02) payroll with FTE line 241 is prorated across all of the PI’s projects. Other 13U02 spending is listed below for manual association.',
  },
  {
    id: 'excluded',
    label: 'Under $100',
    note: '204 projects whose direct expenses total under $100 get no auto-associations this cycle. Final reports add them back.',
  },
  {
    id: 'fte',
    label: 'FTE over 1.0',
    note: 'Employees whose included payroll FTE adds up to more than 1.0. Review only.',
  },
  {
    id: 'totals',
    label: 'Pre-association totals',
    note: 'Included expenses and FTE by OrgR, financial department and SFN before any association. Use it to spot anything far off.',
  },
  {
    id: 'job-codes',
    label: 'Unmatched job codes',
    note: 'Payroll job codes with no FTE line. Their dollars are included; their FTE cannot be reported until the title or staff type is classified.',
  },
];

export function buildExists(build: AutoAssociationBuild | null | undefined): boolean {
  return build !== null && build !== undefined;
}

const currency = new Intl.NumberFormat('en-US', { currency: 'USD', style: 'currency' });

export function formatCurrency(value: number): string {
  return currency.format(value);
}

export function formatFte(value: number): string {
  return value.toFixed(3);
}
