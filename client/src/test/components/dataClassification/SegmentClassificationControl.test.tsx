import { describe, expect, it, vi } from 'vitest';
import { fireEvent, render, screen } from '@testing-library/react';
import type { ChartStringSegment } from '@/queries/chartStringSegments.ts';
import { SegmentClassificationControl } from '@/components/dataClassification/SegmentClassificationControl.tsx';

const unsetAccount: ChartStringSegment = {
  code: '500000',
  description: 'Supplies',
  hierarchy: [],
  includeInReport: null,
  segmentType: 'Account',
  sfn: null,
};

const unsetFund: ChartStringSegment = {
  code: '70575',
  description: 'Berry',
  hierarchy: [],
  includeInReport: null,
  segmentType: 'Fund',
  sfn: null,
};

describe('SegmentClassificationControl', () => {
  it('calls onClassify with (true, null) when Include is clicked on a non-fund', () => {
    const onClassify = vi.fn();
    render(<SegmentClassificationControl onClassify={onClassify} segment={unsetAccount} />);

    fireEvent.click(screen.getByRole('button', { name: 'Include' }));

    expect(onClassify).toHaveBeenCalledWith(true, null);
  });

  it('renders a dropdown with SFN options for a fund', () => {
    render(<SegmentClassificationControl onClassify={vi.fn()} segment={unsetFund} />);

    expect(screen.getByRole('option', { name: '201 - Hatch Funds' })).toBeInTheDocument();
    expect(screen.getByRole('option', { name: 'Multiple' })).toBeInTheDocument();
    expect(screen.getByRole('option', { name: 'Excluded' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Include' })).not.toBeInTheDocument();
  });

  it('shows SFN descriptions in the fund dropdown', () => {
    render(
      <SegmentClassificationControl
        onClassify={vi.fn()}
        segment={{
          code: '45530',
          description: null,
          hierarchy: [],
          includeInReport: null,
          segmentType: 'Fund',
          sfn: null,
        }}
      />
    );
    expect(
      screen.getByRole('option', {
        name: '204 - Contracts, Grants, Research Coop Agreements',
      })
    ).toBeInTheDocument();
  });

  it('calls onClassify with (true, sfn) when an SFN is selected', () => {
    const onClassify = vi.fn();
    render(<SegmentClassificationControl onClassify={onClassify} segment={unsetFund} />);

    fireEvent.change(screen.getByRole('combobox'), { target: { value: '220' } });

    expect(onClassify).toHaveBeenCalledWith(true, '220');
  });

  it('calls onClassify with (true, "Multiple") when Multiple is selected', () => {
    const onClassify = vi.fn();
    render(<SegmentClassificationControl onClassify={onClassify} segment={unsetFund} />);

    fireEvent.change(screen.getByRole('combobox'), { target: { value: 'Multiple' } });

    expect(onClassify).toHaveBeenCalledWith(true, 'Multiple');
  });

  it('calls onClassify with (false, null) when Excluded is selected', () => {
    const onClassify = vi.fn();
    render(<SegmentClassificationControl onClassify={onClassify} segment={unsetFund} />);

    fireEvent.change(screen.getByRole('combobox'), { target: { value: 'Excluded' } });

    expect(onClassify).toHaveBeenCalledWith(false, null);
  });
});
