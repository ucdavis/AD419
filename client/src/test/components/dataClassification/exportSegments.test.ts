import { describe, expect, it } from 'vitest';
import { buildSegmentExport } from '@/components/dataClassification/exportSegments.ts';
import { SEGMENT_TABS } from '@/components/dataClassification/segments.ts';
import type { SegmentClassification } from '@/queries/segmentClassifications.ts';

const fundTab = SEGMENT_TABS.find((tab) => tab.type === 'Fund')!;
const deptTab = SEGMENT_TABS.find((tab) => tab.type === 'FinancialDepartment')!;
const purposeTab = SEGMENT_TABS.find((tab) => tab.type === 'Purpose')!;

const fund: SegmentClassification = {
  code: '45530',
  description: 'AES State Funds',
  hierarchy: [
    { code: 'STATE', level: 'A', name: 'State Funds' },
    { code: 'APPROP', level: 'B', name: 'Appropriations' },
  ],
  includeInReport: true,
  segmentType: 'Fund',
  sfn: '220',
};

describe('buildSegmentExport', () => {
  it('builds level columns from the letters present and maps rows', () => {
    const { columns, filename, rows } = buildSegmentExport([fund], fundTab);

    expect(filename).toBe('ad419-fund-classification.csv');
    expect(columns.map((c) => c.header)).toEqual([
      'Code',
      'Name',
      'Level A Code',
      'Level A Name',
      'Level B Code',
      'Level B Name',
      'Classification',
      'SFN',
      'SFN Description',
    ]);
    expect(rows[0]).toMatchObject({
      classification: 'Included',
      code: '45530',
      levelACode: 'STATE',
      levelAName: 'State Funds',
      name: 'AES State Funds',
      sfn: '220',
      sfnDescription: 'State Appropriations',
    });
  });

  it('omits SFN columns for non-fund types and labels unset rows', () => {
    const dept: SegmentClassification = {
      ...fund,
      code: 'APLS001',
      hierarchy: [],
      includeInReport: null,
      segmentType: 'FinancialDepartment',
      sfn: null,
    };

    const { columns, rows } = buildSegmentExport([dept], deptTab);

    expect(columns.map((c) => c.header)).toEqual(['Code', 'Name', 'Classification']);
    expect(rows[0].classification).toBe('Unset');
  });

  it('omits hierarchy columns for purpose rows', () => {
    const purpose: SegmentClassification = {
      code: '44',
      description: 'Research',
      hierarchy: [
        { code: '1A', level: 'A', name: 'Purpose Categories' },
        { code: '1D', level: 'B', name: 'Organized Research D' },
      ],
      includeInReport: true,
      segmentType: 'Purpose',
      sfn: null,
    };

    const { columns, filename, rows } = buildSegmentExport([purpose], purposeTab);

    expect(filename).toBe('ad419-purpose-classification.csv');
    expect(columns.map((c) => c.header)).toEqual(['Code', 'Name', 'Classification']);
    expect(rows[0]).toEqual({
      classification: 'Included',
      code: '44',
      name: 'Research',
    });
  });
});
