import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import type { ChartStringSegment } from '@/queries/chartStringSegments.ts';
import { SegmentGrid } from '@/components/dataClassification/SegmentGrid.tsx';

const fundSegments: ChartStringSegment[] = [
  { code: '45530', description: 'AES State Appropriations', includeInReport: true, segmentType: 'Fund', sfn: '220' },
];

const accountSegments: ChartStringSegment[] = [
  { code: '500000', description: 'Supplies and Expense', includeInReport: null, segmentType: 'Account', sfn: null },
];

describe('SegmentGrid', () => {
  it('shows the SFN column for the Fund tab', () => {
    render(<SegmentGrid onClassify={vi.fn()} segments={fundSegments} segmentType="Fund" />);

    expect(screen.getByText('SFN')).toBeInTheDocument();
    expect(screen.getByText('45530')).toBeInTheDocument();
  });

  it('omits the SFN column for non-Fund tabs', () => {
    render(<SegmentGrid onClassify={vi.fn()} segments={accountSegments} segmentType="Account" />);

    expect(screen.queryByText('SFN')).not.toBeInTheDocument();
    expect(screen.getByText('500000')).toBeInTheDocument();
  });
});
