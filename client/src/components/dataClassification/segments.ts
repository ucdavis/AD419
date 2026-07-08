import type {
  SegmentClassification,
  SegmentType,
} from '@/queries/segmentClassifications.ts';

export interface SegmentTab {
  classificationHeader: string;
  label: string;
  note: string;
  slug: string;
  type: SegmentType;
}

export const SEGMENT_TABS: SegmentTab[] = [
  {
    classificationHeader: 'Is AES?',
    label: 'Financial Dept',
    note: 'Departments marked AES have their expenses considered for the AD419 report.',
    slug: 'financial-dept',
    type: 'FinancialDepartment',
  },
  {
    classificationHeader: 'Include in AD419?',
    label: 'Natural Account',
    note: 'Whether expenses on this natural account are considered for the AD419 report.',
    slug: 'natural-account',
    type: 'Account',
  },
  {
    classificationHeader: 'SFN',
    label: 'Fund',
    note: 'Included funds must be assigned an SFN. If a fund does not map to a single SFN, select Multiple.',
    slug: 'fund',
    type: 'Fund',
  },
  {
    classificationHeader: 'Include in AD419?',
    label: 'Activity',
    note: 'Whether expenses on this activity are considered for the AD419 report.',
    slug: 'activity',
    type: 'Activity',
  },
  {
    classificationHeader: 'Include in AD419?',
    label: 'Purpose',
    note: 'All purposes are included for transactions with fund 13U02, regardless of classification.',
    slug: 'purpose',
    type: 'Purpose',
  },
  {
    classificationHeader: 'Include in FTE?',
    label: 'ERN',
    note: 'ERN code classification affects FTE calculations only. It does not affect dollar-amount calculations.',
    slug: 'ern',
    type: 'Ern',
  },
];

export function segmentsForType(
  segments: SegmentClassification[],
  type: SegmentType
): SegmentClassification[] {
  return segments.filter((segment) => segment.segmentType === type);
}

export function unclassifiedCount(
  segments: SegmentClassification[],
  type: SegmentType
): number {
  return segmentsForType(segments, type).filter(
    (segment) => segment.includeInReport === null
  ).length;
}

export function allClassified(segments: SegmentClassification[]): boolean {
  return segments.every((segment) => segment.includeInReport !== null);
}
