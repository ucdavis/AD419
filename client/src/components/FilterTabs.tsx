import type { FilterTab } from '../types.ts';

export function FilterTabs({
  activeId,
  tabs,
}: {
  activeId: string;
  tabs: FilterTab[];
}) {
  return (
    <div className="workflow-tabs" role="tablist">
      {tabs.map((tab) => (
        <button
          aria-selected={tab.id === activeId}
          className={tab.id === activeId ? 'workflow-tab is-active' : 'workflow-tab'}
          key={tab.id}
          role="tab"
          type="button"
        >
          <span>{tab.label}</span>
          {tab.count ? <strong>{tab.count}</strong> : null}
        </button>
      ))}
    </div>
  );
}
