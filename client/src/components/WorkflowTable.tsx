import type { ReactNode } from 'react';

export interface WorkflowTableColumn<T> {
  align?: 'left' | 'right';
  header: string;
  id: string;
  render: (row: T) => ReactNode;
}

export function WorkflowTable<T>({
  columns,
  getRowKey,
  rows,
}: {
  columns: WorkflowTableColumn<T>[];
  getRowKey: (row: T) => string;
  rows: T[];
}) {
  return (
    <div className="workflow-table-wrap">
      <table className="workflow-table">
        <thead>
          <tr>
            {columns.map((column) => (
              <th
                className={column.align === 'right' ? 'text-right' : undefined}
                key={column.id}
                scope="col"
              >
                {column.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={getRowKey(row)}>
              {columns.map((column) => (
                <td
                  className={column.align === 'right' ? 'text-right' : undefined}
                  key={column.id}
                >
                  {column.render(row)}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
