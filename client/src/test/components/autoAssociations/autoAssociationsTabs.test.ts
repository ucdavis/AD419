import { describe, expect, it } from 'vitest';
import {
  AUTO_ASSOCIATIONS_TABS,
  buildExists,
  formatCurrency,
  formatFte,
} from '@/components/autoAssociations/autoAssociationsTabs.ts';

describe('autoAssociationsTabs', () => {
  it('lists every report tab once', () => {
    expect(AUTO_ASSOCIATIONS_TABS.map((tab) => tab.id)).toEqual([
      'rule-204',
      'rule-20x',
      'rule-220',
      'excluded',
      'fte',
      'totals',
      'job-codes',
    ]);
  });

  it('opens the gate only when a build exists', () => {
    expect(buildExists(null)).toBe(false);
    expect(buildExists(undefined)).toBe(false);
    expect(
      buildExists({
        associationRows: 0,
        buildId: 1,
        builtAt: '2026-07-07T12:00:00Z',
        cycleEnd: '2026-09-30',
        cycleStart: '2025-10-01',
        excludedProjects: 0,
        misclassified204Rows: 0,
        summaryRows: 0,
      })
    ).toBe(true);
  });

  it('formats money and FTE for the tables', () => {
    expect(formatCurrency(1234.5)).toBe('$1,234.50');
    expect(formatFte(0.125)).toBe('0.125');
  });
});
