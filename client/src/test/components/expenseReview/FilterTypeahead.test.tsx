import { describe, expect, it, vi } from 'vitest';
import { render, screen, within } from '@testing-library/react';
import { userEvent } from '@testing-library/user-event';
import {
  FilterTypeahead,
  MAX_VISIBLE_MATCHES,
  matchFilterOptions,
} from '@/components/expenseReview/FilterTypeahead.tsx';

const accountOptions = [
  { label: '500000 - Salaries', value: '500000' },
  { label: '510000 - Benefits', value: '510000' },
  { label: '531010 - Salary Recharge', value: '531010' },
  { label: '540000 - Supplies', value: '540000' },
];

function renderTypeahead({
  disabled = false,
  options = accountOptions,
  selected = [],
}: {
  disabled?: boolean;
  options?: typeof accountOptions;
  selected?: string[];
} = {}) {
  const onAdd = vi.fn();
  render(
    <FilterTypeahead
      disabled={disabled}
      label="Account"
      onAdd={onAdd}
      options={options}
      selected={selected}
    />
  );

  return {
    input: screen.getByRole('combobox', { name: 'Account filter' }),
    onAdd,
  };
}

function optionNames() {
  return within(screen.getByRole('listbox'))
    .getAllByRole('option')
    .map((option) => option.textContent);
}

describe('matchFilterOptions', () => {
  it('requires every term to match and lists prefix matches first', () => {
    expect(
      matchFilterOptions(accountOptions, 'sal').map((option) => option.value)
    ).toEqual(['500000', '531010']);
    expect(
      matchFilterOptions(accountOptions, '53 salary').map(
        (option) => option.value
      )
    ).toEqual(['531010']);
    expect(
      matchFilterOptions(accountOptions, 'recharge').map(
        (option) => option.value
      )
    ).toEqual(['531010']);
    expect(
      matchFilterOptions(
        [
          { label: 'Excluded by fund', value: 'fund:excluded' },
          { label: 'Fund is unresolved', value: 'fund:unresolved' },
        ],
        'fund'
      ).map((option) => option.value)
    ).toEqual(['fund:excluded', 'fund:unresolved']);
    expect(
      matchFilterOptions(
        [
          { label: 'Excluded by fund', value: 'excluded' },
          { label: 'Fund is unresolved', value: 'unresolved' },
        ],
        'fund'
      ).map((option) => option.value)
    ).toEqual(['unresolved', 'excluded']);
  });

  it('returns every option for a blank query', () => {
    expect(matchFilterOptions(accountOptions, '   ')).toEqual(accountOptions);
  });
});

describe('FilterTypeahead', () => {
  it('narrows options as the user types and adds the clicked option', async () => {
    const user = userEvent.setup();
    const { input, onAdd } = renderTypeahead();

    await user.click(input);
    expect(optionNames()).toHaveLength(4);

    await user.type(input, 'supp');
    expect(optionNames()).toEqual(['540000 - Supplies']);

    await user.click(screen.getByRole('option', { name: '540000 - Supplies' }));
    expect(onAdd).toHaveBeenCalledWith('540000');
    expect(input).toHaveValue('');
    expect(screen.queryByRole('listbox')).not.toBeInTheDocument();
  });

  it('supports arrow keys, Enter, and Escape', async () => {
    const user = userEvent.setup();
    const { input, onAdd } = renderTypeahead();

    await user.click(input);
    await user.keyboard('{ArrowDown}{ArrowDown}');
    expect(
      screen.getByRole('option', { name: '531010 - Salary Recharge' })
    ).toHaveAttribute('aria-selected', 'true');
    expect(input).toHaveAttribute(
      'aria-activedescendant',
      screen.getByRole('option', { name: '531010 - Salary Recharge' }).id
    );

    await user.keyboard('{ArrowUp}{ArrowUp}{ArrowUp}');
    expect(
      screen.getByRole('option', { name: '540000 - Supplies' })
    ).toHaveAttribute('aria-selected', 'true');

    await user.keyboard('{Enter}');
    expect(onAdd).toHaveBeenCalledWith('540000');

    await user.type(input, 'ben');
    expect(screen.getByRole('listbox')).toBeInTheDocument();
    await user.keyboard('{Escape}');
    expect(screen.queryByRole('listbox')).not.toBeInTheDocument();
    expect(input).toHaveValue('ben');
    await user.keyboard('{Escape}');
    expect(input).toHaveValue('');
  });

  it('hides options that are already selected', async () => {
    const user = userEvent.setup();
    const { input } = renderTypeahead({ selected: ['500000', '510000'] });

    await user.click(input);
    expect(optionNames()).toEqual([
      '531010 - Salary Recharge',
      '540000 - Supplies',
    ]);
  });

  it('is disabled when every option is selected', () => {
    const { input } = renderTypeahead({
      selected: accountOptions.map((option) => option.value),
    });

    expect(input).toBeDisabled();
  });

  it('shows a no-match message', async () => {
    const user = userEvent.setup();
    const { input, onAdd } = renderTypeahead();

    await user.type(input, 'zzz');
    expect(screen.getByText('No matches')).toBeInTheDocument();
    await user.keyboard('{Enter}');
    expect(onAdd).not.toHaveBeenCalled();
  });

  it('caps the rendered list and tells the user to keep typing', async () => {
    const user = userEvent.setup();
    const manyOptions = Array.from({ length: 1200 }, (_, index) => {
      const code = String(500_000 + index);
      return { label: `${code} - Account ${index}`, value: code };
    });
    const { input } = renderTypeahead({ options: manyOptions });

    await user.click(input);
    expect(optionNames()).toHaveLength(MAX_VISIBLE_MATCHES);
    expect(
      screen.getByText(
        `Showing ${MAX_VISIBLE_MATCHES} of 1,200 matches. Keep typing to narrow.`
      )
    ).toBeInTheDocument();

    await user.type(input, '50119');
    expect(optionNames()).toEqual([
      '501190 - Account 1190',
      '501191 - Account 1191',
      '501192 - Account 1192',
      '501193 - Account 1193',
      '501194 - Account 1194',
      '501195 - Account 1195',
      '501196 - Account 1196',
      '501197 - Account 1197',
      '501198 - Account 1198',
      '501199 - Account 1199',
    ]);
    expect(screen.queryByText(/Keep typing/)).not.toBeInTheDocument();
  });
});
