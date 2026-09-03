import { describe, expect, it } from 'vitest';
import {
  allMapped,
  ORGR_TABS,
  unmappedCount,
  unmappedFirst,
} from '@/components/orgrReview/orgrTabs.ts';

describe('orgrTabs', () => {
  it('lists the four tabs in order', () => {
    expect(ORGR_TABS.map((tab) => tab.id)).toEqual([
      'orgrs',
      'financial-departments',
      'nifa-departments',
      'projects',
    ]);
  });

  it('counts rows with no OrgR', () => {
    expect(unmappedCount([{ orgR: null }, { orgR: 'AARE' }, { orgR: null }])).toBe(2);
  });

  it('gate opens only when every department and nifa row is mapped', () => {
    expect(allMapped([{ orgR: 'AARE' }], [{ orgR: null }])).toBe(false);
    expect(allMapped([{ orgR: 'AARE' }], [{ orgR: 'AARE' }])).toBe(true);
    expect(allMapped([], [])).toBe(true);
  });

  it('sorts unmapped rows first, then by code', () => {
    const rows = [
      { code: 'BBB', orgR: 'AARE' },
      { code: 'AAA', orgR: null },
      { code: 'CCC', orgR: null },
    ];
    expect(unmappedFirst(rows, (row) => row.code).map((row) => row.code)).toEqual([
      'AAA',
      'CCC',
      'BBB',
    ]);
  });
});
