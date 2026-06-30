import { describe, expect, it, vi } from 'vitest';
import { fireEvent, render, screen } from '@testing-library/react';
import type { ChartStringSegment } from '@/queries/chartStringSegments.ts';
import { SegmentClassificationControl } from '@/components/dataClassification/SegmentClassificationControl.tsx';

const unsetSegment: ChartStringSegment = {
  code: '70575',
  description: 'Berry',
  includeInReport: null,
  segmentType: 'Fund',
  sfn: '219',
};

describe('SegmentClassificationControl', () => {
  it('shows an Unset badge when the segment is unclassified', () => {
    render(<SegmentClassificationControl onClassify={vi.fn()} segment={unsetSegment} />);

    expect(screen.getByText('Unset')).toBeInTheDocument();
  });

  it('calls onClassify with true when Include is clicked', () => {
    const onClassify = vi.fn();
    render(<SegmentClassificationControl onClassify={onClassify} segment={unsetSegment} />);

    fireEvent.click(screen.getByRole('button', { name: 'Include' }));

    expect(onClassify).toHaveBeenCalledWith(true);
  });
});
