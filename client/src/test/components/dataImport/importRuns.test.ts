import { describe, expect, it } from 'vitest';
import { bufferedImportWindow } from '@/queries/importRuns.ts';

describe('bufferedImportWindow', () => {
  it('extends the cycle by 3 months on each end', () => {
    expect(bufferedImportWindow('2025-10-01', '2026-09-30')).toEqual({
      windowEnd: '2026-12-30',
      windowStart: '2025-07-01',
    });
  });

  it('clamps to the last day of the target month like .NET AddMonths', () => {
    expect(bufferedImportWindow('2025-11-30', '2025-11-30')).toEqual({
      windowEnd: '2026-02-28',
      windowStart: '2025-08-30',
    });
  });
});
