import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import type { ChartStringSegment } from '@/queries/chartStringSegments.ts';
import { SegmentGrid } from '@/components/dataClassification/SegmentGrid.tsx';

const fundSegments: ChartStringSegment[] = [
  {
    code: '45530',
    description: 'AES State Appropriations',
    hierarchy: [
      { code: 'STATE', level: '0', name: 'State Funds' },
      { code: 'APPROP', level: '1', name: 'Appropriations' },
    ],
    includeInReport: true,
    segmentType: 'Fund',
    sfn: '220',
  },
];

const accountSegments: ChartStringSegment[] = [
  {
    code: '500000',
    description: 'Supplies and Expense',
    hierarchy: [],
    includeInReport: null,
    segmentType: 'Account',
    sfn: null,
  },
];

describe('SegmentGrid', () => {
  it('renders each hierarchy level code with the description as a hover title', () => {
    render(<SegmentGrid onClassify={vi.fn()} segments={fundSegments} segmentType="Fund" />);

    const state = screen.getByText('STATE');
    expect(state).toHaveAttribute('title', 'State Funds');
    expect(state).toHaveClass('cursor-help');
    expect(screen.getByText('APPROP')).toHaveAttribute('title', 'Appropriations');
  });

  it('renders an em dash when a segment has no hierarchy', () => {
    render(<SegmentGrid onClassify={vi.fn()} segments={accountSegments} segmentType="Account" />);

    expect(screen.getByText('—')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Include' })).toBeInTheDocument();
  });
});
