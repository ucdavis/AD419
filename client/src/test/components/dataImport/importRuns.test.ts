import { describe, expect, it } from 'vitest';
import { defaultCycleDates } from '@/queries/importRuns.ts';

describe('defaultCycleDates', () => {
  it('uses the federal fiscal year containing today', () => {
    expect(defaultCycleDates(new Date('2026-07-29'))).toEqual({
      cycleEnd: '2026-09-30',
      cycleStart: '2025-10-01',
    });
    expect(defaultCycleDates(new Date('2026-11-15'))).toEqual({
      cycleEnd: '2027-09-30',
      cycleStart: '2026-10-01',
    });
  });
});
