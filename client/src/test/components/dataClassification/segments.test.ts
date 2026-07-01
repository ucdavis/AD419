import { describe, expect, it } from 'vitest';
import type { ChartStringSegment } from '@/queries/chartStringSegments.ts';
import {
  allClassified,
  SEGMENT_TABS,
  segmentsForType,
  unclassifiedCount,
} from '@/components/dataClassification/segments.ts';

const segments: ChartStringSegment[] = [
  { code: '45530', description: 'AES', hierarchy: [], includeInReport: true, segmentType: 'Fund', sfn: '220' },
  { code: '70575', description: 'Berry', hierarchy: [], includeInReport: null, segmentType: 'Fund', sfn: '219' },
  { code: '500000', description: 'S and E', hierarchy: [], includeInReport: null, segmentType: 'Account', sfn: null },
];

describe('data classification segment helpers', () => {
  it('exposes the tabs in display order, including ERN', () => {
    expect(SEGMENT_TABS.map((tab) => tab.type)).toEqual([
      'FinancialDepartment',
      'Account',
      'Fund',
      'Activity',
      'Ern',
    ]);
    expect(SEGMENT_TABS.at(-1)).toEqual({ label: 'ERN', type: 'Ern' });
  });

  it('filters segments by type', () => {
    expect(segmentsForType(segments, 'Fund')).toHaveLength(2);
    expect(segmentsForType(segments, 'Account')).toHaveLength(1);
  });

  it('counts unclassified segments per type', () => {
    expect(unclassifiedCount(segments, 'Fund')).toBe(1);
    expect(unclassifiedCount(segments, 'Account')).toBe(1);
    expect(unclassifiedCount(segments, 'Activity')).toBe(0);
  });

  it('reports the gate as closed while any segment is unclassified', () => {
    expect(allClassified(segments)).toBe(false);
    expect(allClassified(segments.filter((s) => s.includeInReport !== null))).toBe(true);
  });
});
