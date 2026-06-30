import type {
  ChartStringSegment,
  SegmentType,
} from '@/queries/chartStringSegments.ts';

export const SEGMENT_TABS: { label: string; type: SegmentType }[] = [
  { label: 'Financial Dept', type: 'FinancialDepartment' },
  { label: 'Natural Account', type: 'Account' },
  { label: 'Fund', type: 'Fund' },
  { label: 'Activity', type: 'Activity' },
];

export function segmentsForType(
  segments: ChartStringSegment[],
  type: SegmentType
): ChartStringSegment[] {
  return segments.filter((segment) => segment.segmentType === type);
}

export function unclassifiedCount(
  segments: ChartStringSegment[],
  type: SegmentType
): number {
  return segmentsForType(segments, type).filter(
    (segment) => segment.includeInReport === null
  ).length;
}

export function allClassified(segments: ChartStringSegment[]): boolean {
  return segments.every((segment) => segment.includeInReport !== null);
}
