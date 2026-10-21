import type { ExpenseReviewFilterOption } from '@/queries/expenseReview.ts';
import { type KeyboardEvent, useId, useRef, useState } from 'react';

export const MAX_VISIBLE_MATCHES = 50;

// Every whitespace-separated term must appear in the code or label. Options
// whose code or label starts with the first term are listed first.
export function matchFilterOptions(
  options: ExpenseReviewFilterOption[],
  query: string
) {
  const terms = query.trim().toLowerCase().split(/\s+/).filter(Boolean);
  if (terms.length === 0) {
    return options;
  }

  const matches = options.filter((option) => {
    const text = `${option.value} ${option.label}`.toLowerCase();
    return terms.every((term) => text.includes(term));
  });
  const startsWithFirstTerm = (option: ExpenseReviewFilterOption) =>
    option.value.toLowerCase().startsWith(terms[0]) ||
    option.label.toLowerCase().startsWith(terms[0]);

  return [
    ...matches.filter(startsWithFirstTerm),
    ...matches.filter((option) => !startsWithFirstTerm(option)),
  ];
}

export function FilterTypeahead({
  disabled,
  label,
  onAdd,
  options,
  selected,
}: {
  disabled: boolean;
  label: string;
  onAdd: (value: string) => void;
  options: ExpenseReviewFilterOption[];
  selected: string[];
}) {
  const inputId = useId();
  const listboxId = useId();
  const listRef = useRef<HTMLUListElement>(null);
  const [query, setQuery] = useState('');
  const [isOpen, setIsOpen] = useState(false);
  const [activeIndex, setActiveIndex] = useState(0);

  const availableOptions = options.filter(
    (option) => !selected.includes(option.value)
  );
  const matches = matchFilterOptions(availableOptions, query);
  const visibleMatches = matches.slice(0, MAX_VISIBLE_MATCHES);
  const isDisabled = disabled || availableOptions.length === 0;
  const showList = isOpen && !isDisabled;
  const highlightedIndex = Math.min(activeIndex, visibleMatches.length - 1);
  const optionId = (index: number) => `${listboxId}-option-${index}`;

  const choose = (option: ExpenseReviewFilterOption) => {
    onAdd(option.value);
    setQuery('');
    setActiveIndex(0);
    setIsOpen(false);
  };

  const moveHighlight = (delta: number) => {
    if (!showList) {
      setIsOpen(true);
      return;
    }
    if (visibleMatches.length === 0) {
      return;
    }

    const next =
      (highlightedIndex + delta + visibleMatches.length) %
      visibleMatches.length;
    setActiveIndex(next);
    listRef.current?.children[next]?.scrollIntoView?.({ block: 'nearest' });
  };

  const handleKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    if (event.key === 'ArrowDown') {
      event.preventDefault();
      moveHighlight(1);
    } else if (event.key === 'ArrowUp') {
      event.preventDefault();
      moveHighlight(-1);
    } else if (event.key === 'Enter') {
      const option = showList ? visibleMatches[highlightedIndex] : undefined;
      if (option) {
        event.preventDefault();
        choose(option);
      }
    } else if (event.key === 'Escape') {
      if (showList) {
        setIsOpen(false);
      } else {
        setQuery('');
      }
    }
  };

  return (
    <div className="form-control w-full">
      <label className="label-text" htmlFor={inputId}>
        {label}
      </label>
      <div className="relative">
        <input
          aria-activedescendant={
            showList && highlightedIndex >= 0
              ? optionId(highlightedIndex)
              : undefined
          }
          aria-autocomplete="list"
          aria-controls={listboxId}
          aria-expanded={showList}
          aria-label={`${label} filter`}
          autoComplete="off"
          className="input input-bordered input-sm w-full"
          disabled={isDisabled}
          id={inputId}
          onBlur={() => setIsOpen(false)}
          onChange={(event) => {
            setQuery(event.target.value);
            setActiveIndex(0);
            setIsOpen(true);
          }}
          onClick={() => setIsOpen(true)}
          onKeyDown={handleKeyDown}
          placeholder="Any"
          role="combobox"
          type="text"
          value={query}
        />
        {showList ? (
          <div className="absolute z-20 mt-1 w-full min-w-64 rounded-box border border-base-300 bg-base-100 shadow-lg">
            <ul
              aria-label={`${label} options`}
              className="max-h-64 overflow-y-auto py-1"
              id={listboxId}
              ref={listRef}
              role="listbox"
            >
              {visibleMatches.map((option, index) => (
                <li
                  aria-selected={index === highlightedIndex}
                  className={`cursor-pointer px-3 py-1.5 text-sm ${
                    index === highlightedIndex ? 'bg-base-200' : ''
                  }`}
                  id={optionId(index)}
                  key={option.value}
                  onClick={() => choose(option)}
                  // Keep focus in the input so blur does not close the list
                  // before the click lands.
                  onMouseDown={(event) => event.preventDefault()}
                  onMouseEnter={() => setActiveIndex(index)}
                  role="option"
                >
                  {option.label}
                </li>
              ))}
            </ul>
            {visibleMatches.length === 0 ? (
              <div className="px-3 py-2 text-sm text-base-content/60">
                No matches
              </div>
            ) : null}
            {matches.length > visibleMatches.length ? (
              <div className="border-t border-base-300 px-3 py-2 text-xs text-base-content/60">
                Showing {visibleMatches.length} of{' '}
                {matches.length.toLocaleString()} matches. Keep typing to
                narrow.
              </div>
            ) : null}
          </div>
        ) : null}
      </div>
    </div>
  );
}
