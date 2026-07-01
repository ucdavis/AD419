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
  it('renders a column per hierarchy level with the code and hover title', () => {
    render(<SegmentGrid onClassify={vi.fn()} segments={fundSegments} segmentType="Fund" />);

    expect(screen.getByRole('columnheader', { name: 'Level 0' })).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'Level 1' })).toBeInTheDocument();

    const state = screen.getByText('STATE');
    expect(state).toHaveAttribute('data-tip', 'State Funds');
    expect(state).toHaveClass('cursor-help');
    expect(screen.getByText('APPROP')).toHaveAttribute('data-tip', 'Appropriations');
  });

  it('renders no level columns when no segment has a hierarchy', () => {
    render(<SegmentGrid onClassify={vi.fn()} segments={accountSegments} segmentType="Account" />);

    expect(screen.queryByRole('columnheader', { name: /^Level / })).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Include' })).toBeInTheDocument();
  });
});
