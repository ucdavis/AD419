import type { ExpenseReviewFilterOption } from '@/queries/expenseReview.ts';
import {
  type KeyboardEvent,
  useEffect,
  useEffectEvent,
  useId,
  useRef,
  useState,
} from 'react';

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

type FilterTypeaheadProps = {
  ariaLabel?: string;
  disabled: boolean;
  label: string;
  options: ExpenseReviewFilterOption[];
  placeholder?: string;
  selected: string[];
} & (
  | {
      keepChoice?: boolean;
      onAdd: (value: string) => void;
      onDraftDirtyChange?: never;
      onEdit?: () => void;
      onSelectionChange?: never;
    }
  | {
      keepChoice?: never;
      onAdd?: never;
      onDraftDirtyChange?: (dirty: boolean) => void;
      onEdit?: never;
      onSelectionChange: (values: string[]) => void;
    }
);

function sameSelection(left: string[], right: string[]) {
  if (left === right) {
    return true;
  }
  const leftValues = new Set(left);
  const rightValues = new Set(right);
  return (
    leftValues.size === rightValues.size &&
    [...leftValues].every((value) => rightValues.has(value))
  );
}

export function FilterTypeahead({
  ariaLabel,
  disabled,
  keepChoice = false,
  label,
  onAdd,
  onDraftDirtyChange,
  onEdit,
  onSelectionChange,
  options,
  placeholder = 'Any',
  selected,
}: FilterTypeaheadProps) {
  const inputId = useId();
  const listboxId = useId();
  const containerRef = useRef<HTMLDivElement>(null);
  const listRef = useRef<HTMLUListElement>(null);
  const openingSelection = useRef<string[] | null>(null);
  const [query, setQuery] = useState('');
  const [draft, setDraft] = useState<string[] | null>(null);
  const [activeIndex, setActiveIndex] = useState(0);

  const isMulti = onSelectionChange !== undefined;
  const availableOptions = isMulti
    ? options
    : options.filter((option) => !selected.includes(option.value));
  const matches = matchFilterOptions(availableOptions, query);
  const visibleMatches = matches.slice(0, MAX_VISIBLE_MATCHES);
  const isDisabled =
    disabled || (availableOptions.length === 0 && !(isMulti && draft));
  const showList = draft !== null && !isDisabled;
  const selectedValues = draft ?? selected;
  const highlightedIndex = Math.min(activeIndex, visibleMatches.length - 1);
  const optionId = (index: number) => `${listboxId}-option-${index}`;

  const open = () => {
    if (!openingSelection.current) {
      openingSelection.current = selected;
      setDraft(selected);
    }
  };

  const close = () => {
    const initial = openingSelection.current;
    if (!initial) {
      return;
    }
    // An outside pointer press can also cause blur. Commit once per opening.
    openingSelection.current = null;
    setDraft(null);
    if (onSelectionChange && draft) {
      setQuery('');
      setActiveIndex(0);
      if (!sameSelection(initial, draft)) {
        onSelectionChange(draft);
      }
      onDraftDirtyChange?.(false);
    }
  };

  // Disabled controls and targets that suppress mousedown may not move focus.
  const handleOutsidePointer = useEffectEvent((event: PointerEvent) => {
    const container = containerRef.current;
    if (container && !event.composedPath().includes(container)) {
      close();
    }
  });
  useEffect(() => {
    if (!showList || !isMulti) {
      return;
    }
    document.addEventListener('pointerdown', handleOutsidePointer, true);
    return () =>
      document.removeEventListener('pointerdown', handleOutsidePointer, true);
  }, [isMulti, showList]);

  const choose = (option: ExpenseReviewFilterOption) => {
    if (onSelectionChange) {
      const next = selectedValues.includes(option.value)
        ? selectedValues.filter((value) => value !== option.value)
        : [...selectedValues, option.value];
      setDraft(next);
      onDraftDirtyChange?.(!sameSelection(next, selected));
      return;
    }
    onAdd(option.value);
    setQuery(keepChoice ? option.label : '');
    setActiveIndex(0);
    close();
  };

  const moveHighlight = (delta: number) => {
    if (!showList) {
      open();
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
        close();
      } else {
        setQuery('');
        onEdit?.();
      }
    }
  };

  return (
    <div
      className="form-control w-full"
      onBlur={(event) => {
        if (!event.currentTarget.contains(event.relatedTarget)) {
          close();
        }
      }}
      ref={containerRef}
    >
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
          aria-label={ariaLabel ?? `${label} filter`}
          autoComplete="off"
          className="input input-bordered input-sm w-full"
          disabled={isDisabled}
          id={inputId}
          onChange={(event) => {
            setQuery(event.target.value);
            setActiveIndex(0);
            open();
            onEdit?.();
          }}
          onClick={open}
          onKeyDown={handleKeyDown}
          placeholder={
            isMulti && selectedValues.length > 0
              ? `${selectedValues.length} selected`
              : placeholder
          }
          role="combobox"
          type="text"
          value={query}
        />
        {showList ? (
          <div
            className="absolute z-20 mt-1 w-full min-w-64 rounded-box border border-base-300 bg-base-100 shadow-lg"
            // Keep focus in the input for clicks anywhere inside the popup.
            onMouseDown={(event) => event.preventDefault()}
          >
            <ul
              aria-label={`${label} options`}
              aria-multiselectable={isMulti || undefined}
              className="max-h-64 overflow-y-auto py-1"
              id={listboxId}
              ref={listRef}
              role="listbox"
            >
              {visibleMatches.map((option, index) => (
                <li
                  aria-selected={
                    isMulti
                      ? selectedValues.includes(option.value)
                      : index === highlightedIndex
                  }
                  className={`flex cursor-pointer items-center gap-2 px-3 py-1.5 text-sm ${
                    index === highlightedIndex ? 'bg-base-200' : ''
                  }`}
                  id={optionId(index)}
                  key={option.value}
                  onClick={() => choose(option)}
                  onMouseEnter={() => setActiveIndex(index)}
                  role="option"
                >
                  {isMulti ? (
                    <span
                      aria-checked={selectedValues.includes(option.value)}
                      aria-hidden="true"
                      className="checkbox checkbox-primary checkbox-xs"
                      role="checkbox"
                    />
                  ) : null}
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
