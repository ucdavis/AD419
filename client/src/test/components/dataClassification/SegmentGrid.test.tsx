import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import type { SegmentClassification } from '@/queries/segmentClassifications.ts';
import { SegmentGrid } from '@/components/dataClassification/SegmentGrid.tsx';

function account(
  code: string,
  includeInReport: boolean | null
): SegmentClassification {
  return { code, description: `Name ${code}`, hierarchy: [], includeInReport, segmentType: 'Account', sfn: null };
}

// True when `first` appears before `second` in the DOM.
function isBefore(first: HTMLElement, second: HTMLElement): boolean {
  return Boolean(
    first.compareDocumentPosition(second) & Node.DOCUMENT_POSITION_FOLLOWING
  );
}

const fundSegments: SegmentClassification[] = [
  {
    code: '45530',
    description: 'AES State Appropriations',
    hierarchy: [
      { code: 'STATE', level: 'A', name: 'State Funds' },
      { code: 'APPROP', level: 'B', name: 'Appropriations' },
    ],
    includeInReport: true,
    segmentType: 'Fund',
    sfn: '220',
  },
];

const accountSegments: SegmentClassification[] = [
  {
    code: '500000',
    description: 'Supplies and Expense',
    hierarchy: [],
    includeInReport: null,
    segmentType: 'Account',
    sfn: null,
  },
];

const purposeSegments: SegmentClassification[] = [
  {
    code: '44',
    description: 'Research',
    hierarchy: [
      { code: '1A', level: 'A', name: 'Purpose Categories' },
      { code: '1D', level: 'B', name: 'Organized Research D' },
    ],
    includeInReport: true,
    segmentType: 'Purpose',
    sfn: null,
  },
];

describe('SegmentGrid', () => {
  it('renders a column per hierarchy level with the code and hover title', () => {
    render(<SegmentGrid classificationHeader="SFN" onClassify={vi.fn()} segments={fundSegments} segmentType="Fund" />);

    expect(screen.getByRole('columnheader', { name: 'Level A' })).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'Level B' })).toBeInTheDocument();

    const state = screen.getByText('STATE');
    expect(state).toHaveAttribute('data-tip', 'State Funds');
    expect(state).toHaveClass('cursor-help');
    expect(screen.getByText('APPROP')).toHaveAttribute('data-tip', 'Appropriations');
  });

  it('renders the passed classification header', () => {
    render(<SegmentGrid classificationHeader="Is AES?" onClassify={vi.fn()} segments={accountSegments} segmentType="Account" />);

    expect(screen.getByRole('columnheader', { name: 'Is AES?' })).toBeInTheDocument();
    expect(screen.queryByRole('columnheader', { name: 'Classification' })).not.toBeInTheDocument();
  });

  it('renders no level columns when no segment has a hierarchy', () => {
    render(<SegmentGrid classificationHeader="Include in AD419?" onClassify={vi.fn()} segments={accountSegments} segmentType="Account" />);

    expect(screen.queryByRole('columnheader', { name: /^Level / })).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Include' })).toBeInTheDocument();
  });

  it('hides hierarchy level columns for purpose segments', () => {
    render(<SegmentGrid classificationHeader="Include in AD419?" onClassify={vi.fn()} segments={purposeSegments} segmentType="Purpose" />);

    expect(screen.getByRole('columnheader', { name: 'Code' })).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'Name' })).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'Include in AD419?' })).toBeInTheDocument();
    expect(screen.queryByRole('columnheader', { name: 'Level A' })).not.toBeInTheDocument();
    expect(screen.queryByRole('columnheader', { name: 'Level B' })).not.toBeInTheDocument();
    expect(screen.getByText('44')).toBeInTheDocument();
    expect(screen.getByText('Research')).toBeInTheDocument();
  });

  it('sorts unclassified rows to the top by default', () => {
    render(
      <SegmentGrid
        classificationHeader="Include in AD419?"
        onClassify={vi.fn()}
        segments={[account('AAA', true), account('BBB', null)]}
        segmentType="Account"
      />
    );

    // BBB is unclassified, so it renders before the classified AAA.
    expect(isBefore(screen.getByText('BBB'), screen.getByText('AAA'))).toBe(true);
  });

  it('keeps a row in place when it is classified in the same tab', () => {
    const { rerender } = render(
      <SegmentGrid
        classificationHeader="Include in AD419?"
        onClassify={vi.fn()}
        segments={[account('AAA', true), account('BBB', null)]}
        segmentType="Account"
      />
    );
    expect(isBefore(screen.getByText('BBB'), screen.getByText('AAA'))).toBe(true);

    // BBB gets classified: order is frozen for the tab, so it stays above AAA.
    rerender(
      <SegmentGrid
        classificationHeader="Include in AD419?"
        onClassify={vi.fn()}
        segments={[account('AAA', true), account('BBB', false)]}
        segmentType="Account"
      />
    );
    expect(isBefore(screen.getByText('BBB'), screen.getByText('AAA'))).toBe(true);
  });
});
