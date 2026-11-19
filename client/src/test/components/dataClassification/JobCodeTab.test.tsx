import { describe, expect, it, vi } from 'vitest';
import { fireEvent, render, screen, within } from '@testing-library/react';
import { JobCodeTab } from '@/components/dataClassification/JobCodeTab.tsx';
import {
  blockingJobCodeCount,
  type JobCodeClassification,
  type JobCodeClassifications,
} from '@/queries/jobCodeClassifications.ts';

function jobCode(
  code: string,
  overrides: Partial<JobCodeClassification> = {}
): JobCodeClassification {
  return {
    amount: 100,
    blocking: false,
    employeeCount: 1,
    fte: 0.25,
    fteSfn: null,
    jobCode: code,
    staffTypeCode: null,
    titleName: null,
    ...overrides,
  };
}

const staffTypes = [
  { description: 'Scientist', fteSfn: '241', staffTypeCode: '1S' },
  { description: 'Scientist emeritus', fteSfn: '241', staffTypeCode: '1X' },
  { description: 'Technical Support', fteSfn: '243', staffTypeCode: '3T' },
  { description: null, fteSfn: '247', staffTypeCode: '7U' },
];

const data: JobCodeClassifications = {
  rows: [
    jobCode('0000', { amount: 12_400, blocking: true, employeeCount: 2 }),
    jobCode('4460', {
      amount: 310_220.1,
      employeeCount: 14,
      fte: 6.125,
      fteSfn: '243',
      staffTypeCode: '3T',
      titleName: 'LAB AST 2',
    }),
  ],
  staffTypes,
};

const selectFor = (code: string) =>
  screen.getByRole<HTMLSelectElement>('combobox', { name: `Job SFN for ${code}` });

describe('JobCodeTab', () => {
  it('lists job codes with their title, line, employees, amount and FTE', () => {
    render(<JobCodeTab data={data} onAssign={vi.fn()} />);

    for (const header of ['Job code', 'Title', 'Job SFN', 'Employees', 'Amount', 'FTE']) {
      expect(screen.getByRole('columnheader', { name: header })).toBeInTheDocument();
    }
    const row = screen.getByRole('row', { name: /4460/ });
    expect(within(row).getByText('LAB AST 2')).toBeInTheDocument();
    expect(within(row).getByText('14')).toBeInTheDocument();
    expect(within(row).getByText('$310,220.10')).toBeInTheDocument();
    expect(within(row).getByText('6.125')).toBeInTheDocument();
  });

  it('shows the assigned line and a placeholder for an unassigned code', () => {
    render(<JobCodeTab data={data} onAssign={vi.fn()} />);

    const assigned = selectFor('4460');
    expect(assigned.value).toBe('3T');
    expect(assigned.selectedOptions[0].textContent).toBe('243 Technical Support');

    const unassigned = selectFor('0000');
    expect(unassigned.value).toBe('');
    expect(unassigned.selectedOptions[0].textContent).toBe('Select...');
  });

  it('offers every staff type, including two that share a line, and saves the one picked', () => {
    const onAssign = vi.fn();
    render(<JobCodeTab data={data} onAssign={onAssign} />);

    const select = selectFor('0000');
    expect(within(select).getByRole('option', { name: '241 Scientist' })).toBeInTheDocument();
    expect(within(select).getByRole('option', { name: '241 Scientist emeritus' })).toBeInTheDocument();
    // A staff type with no description shows its line alone.
    expect(within(select).getByRole('option', { name: '247' })).toBeInTheDocument();

    fireEvent.change(select, { target: { value: '1X' } });

    expect(onAssign).toHaveBeenCalledExactlyOnceWith('0000', '1X');
  });

  it('locks only the dropdown of a job code whose save is running', () => {
    render(<JobCodeTab data={data} onAssign={vi.fn()} savingJobCodes={['0000']} />);

    expect(selectFor('0000')).toBeDisabled();
    expect(selectFor('4460')).toBeEnabled();
  });

  it('cannot clear an assignment', () => {
    const onAssign = vi.fn();
    render(<JobCodeTab data={data} onAssign={onAssign} />);

    const placeholder = within(selectFor('4460')).getByRole<HTMLOptionElement>('option', {
      name: 'Select...',
    });
    expect(placeholder.disabled).toBe(true);

    fireEvent.change(selectFor('4460'), { target: { value: '' } });
    expect(onAssign).not.toHaveBeenCalled();
  });

  it('keeps a row in place after it is assigned', () => {
    const { rerender } = render(<JobCodeTab data={data} onAssign={vi.fn()} />);

    // The server sorts assigned codes last; a refetch after saving 0000 must
    // not move the row out from under the user.
    rerender(
      <JobCodeTab
        data={{
          rows: [
            data.rows[1],
            jobCode('0000', { amount: 12_400, employeeCount: 2, fteSfn: '241', staffTypeCode: '1S' }),
          ],
          staffTypes,
        }}
        onAssign={vi.fn()}
      />
    );

    // The table's own page size select is a combobox too.
    const codes = screen
      .getAllByRole('combobox', { name: /^Job SFN for/ })
      .map((select) => select.getAttribute('aria-label'));
    expect(codes).toEqual(['Job SFN for 0000', 'Job SFN for 4460']);
    expect(selectFor('0000').value).toBe('1S');
  });
});

describe('blockingJobCodeCount', () => {
  it('counts only blocking rows', () => {
    expect(
      blockingJobCodeCount([
        jobCode('0000', { blocking: true }),
        jobCode('4446'),
        jobCode('4448', { blocking: true }),
        jobCode('1234', { fteSfn: '241', staffTypeCode: '1S' }),
      ])
    ).toBe(2);
    expect(blockingJobCodeCount([])).toBe(0);
  });
});
