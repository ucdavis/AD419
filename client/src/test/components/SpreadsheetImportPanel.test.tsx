import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen, waitFor, within } from '@testing-library/react';
import { userEvent } from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { SpreadsheetImportPanel } from '@/components/SpreadsheetImportPanel.tsx';
import { server } from '@/test/mswUtils.ts';

describe('SpreadsheetImportPanel', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('uploads the selected file to the selected dataset and shows success', async () => {
    const user = userEvent.setup();
    let postedDataset = '';

    server.use(
      http.get('/api/imports/recent', () => HttpResponse.json([])),
      http.post('/api/imports/:dataset', ({ params }) => {
        postedDataset = String(params.dataset);

        return HttpResponse.json({
          dataset: postedDataset,
          filename: 'active-projects.xlsx',
          importedAt: '2026-06-09T18:30:00Z',
          importLogId: 12,
          rowsImported: 42,
          succeeded: true,
        });
      })
    );

    const { cleanup } = renderPanel();

    try {
      await user.selectOptions(screen.getByLabelText('Dataset'), [
        'active-projects',
      ]);
      await user.upload(
        screen.getByLabelText('Workbook'),
        new File(['test'], 'active-projects.xlsx', {
          type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        })
      );
      await user.click(screen.getByRole('button', { name: 'Upload' }));

      expect(
        await screen.findByText('Imported 42 rows from active-projects.xlsx.')
      ).toBeInTheDocument();
      expect(postedDataset).toBe('active-projects');
    } finally {
      cleanup();
    }
  });

  it('renders validation failures with sortable rows and highlighted cells', async () => {
    const user = userEvent.setup();

    server.use(
      http.get('/api/imports/recent', () => HttpResponse.json([])),
      http.post('/api/imports/:dataset', () =>
        HttpResponse.json(
          {
            attemptedRows: 2,
            dataset: 'all-projects',
            fileErrors: [
              {
                code: 'unknown_header',
                message: 'Header Mystery Column is not recognized.',
                sourceHeader: 'Mystery Column',
              },
            ],
            filename: 'all-projects.xlsx',
            importLogId: 44,
            rows: [
              {
                cellErrors: [
                  {
                    code: 'required',
                    message: 'OrganizationName is required.',
                    rawValue: '',
                    sourceHeader: 'Organization Name',
                    targetColumn: 'OrganizationName',
                  },
                ],
                errors: [],
                rowNum: 5,
                values: {
                  AccessionNumber: 'A-5',
                  OrganizationName: '',
                },
              },
              {
                cellErrors: [
                  {
                    code: 'required',
                    message: 'ProjectDirector is required.',
                    rawValue: '',
                    sourceHeader: 'Project Director',
                    targetColumn: 'ProjectDirector',
                  },
                  {
                    code: 'type_conversion',
                    message: 'LastProgressReportFy must be a whole number.',
                    rawValue: 'FY25',
                    sourceHeader: 'Last Progress Report FY',
                    targetColumn: 'LastProgressReportFy',
                  },
                  {
                    code: 'duplicate_key',
                    message:
                      'Project Number duplicates another row in this file.',
                    rawValue: 'PRJ-1',
                    sourceHeader: 'Project Number',
                    targetColumn: 'ProjectNumber',
                  },
                ],
                errors: [],
                rowNum: 2,
                values: {
                  AccessionNumber: 'A-2',
                  LastProgressReportFy: 'FY25',
                  ProjectDirector: '',
                  ProjectNumber: 'PRJ-1',
                },
              },
            ],
            succeeded: false,
          },
          { status: 400 }
        )
      )
    );

    const { cleanup } = renderPanel();

    try {
      await user.upload(
        screen.getByLabelText('Workbook'),
        new File(['test'], 'all-projects.xlsx', {
          type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        })
      );
      await user.click(screen.getByRole('button', { name: 'Upload' }));

      expect(
        await screen.findByText(
          'Import failed validation for 2 of 2 attempted rows.'
        )
      ).toBeInTheDocument();
      expect(screen.getByText(/Mystery Column/)).toBeInTheDocument();
      expect(
        screen.getByText('OrganizationName is required.')
      ).toBeInTheDocument();
      expect(
        screen.getByRole('columnheader', { name: 'ProjectNumber' })
      ).toHaveClass('text-error');
      expect(screen.getByText('FY25')).toHaveClass('text-error');
      expect(screen.getByText(/ProjectDirector is required.;/)).toHaveAttribute(
        'title',
        expect.stringContaining('Project Number duplicates another row')
      );

      await user.click(screen.getByRole('columnheader', { name: 'Errors' }));
      await user.click(screen.getByRole('columnheader', { name: /Errors/ }));

      await waitFor(() => {
        const bodyRows = within(screen.getByRole('table'))
          .getAllByRole('row')
          .slice(1);

        expect(within(bodyRows[0]).getByText('5')).toBeInTheDocument();
        expect(within(bodyRows[1]).getByText('2')).toBeInTheDocument();
      });
    } finally {
      cleanup();
    }
  });

  it('downloads validation errors as CSV', async () => {
    const user = userEvent.setup();
    const createObjectUrl = vi
      .spyOn(URL, 'createObjectURL')
      .mockReturnValue('blob:validation-errors');
    const revokeObjectUrl = vi
      .spyOn(URL, 'revokeObjectURL')
      .mockImplementation(() => {});
    const click = vi
      .spyOn(HTMLAnchorElement.prototype, 'click')
      .mockImplementation(() => {});

    server.use(
      http.get('/api/imports/recent', () => HttpResponse.json([])),
      http.post('/api/imports/:dataset', () =>
        HttpResponse.json(
          {
            attemptedRows: 1,
            dataset: 'all-projects',
            fileErrors: [],
            filename: 'all-projects.xlsx',
            importLogId: 45,
            rows: [
              {
                cellErrors: [
                  {
                    code: 'required',
                    message: 'OrganizationName is required.',
                    rawValue: '',
                    sourceHeader: 'Organization Name',
                    targetColumn: 'OrganizationName',
                  },
                  {
                    code: 'duplicate_key',
                    message:
                      'Project Number duplicates another row in this file.',
                    rawValue: 'PRJ-1',
                    sourceHeader: 'Project Number',
                    targetColumn: 'ProjectNumber',
                  },
                ],
                errors: [],
                rowNum: 2,
                values: {
                  AccessionNumber: 'A-2',
                  OrganizationName: '',
                  ProjectNumber: 'PRJ-1',
                },
              },
            ],
            succeeded: false,
          },
          { status: 400 }
        )
      )
    );

    const { cleanup } = renderPanel();

    try {
      await user.upload(
        screen.getByLabelText('Workbook'),
        new File(['test'], 'all-projects.xlsx', {
          type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        })
      );
      await user.click(screen.getByRole('button', { name: 'Upload' }));
      await user.click(
        await screen.findByRole('button', { name: 'Download CSV' })
      );

      expect(createObjectUrl).toHaveBeenCalled();
      await expect(
        readBlobText(createObjectUrl.mock.calls[0][0] as Blob)
      ).resolves.toContain(
        '2,ProjectNumber,Project Number,PRJ-1,Project Number duplicates another row in this file.'
      );
      expect(click).toHaveBeenCalled();
      expect(revokeObjectUrl).toHaveBeenCalledWith('blob:validation-errors');
    } finally {
      cleanup();
    }
  });
});

function renderPanel() {
  const queryClient = new QueryClient({
    defaultOptions: {
      mutations: { retry: false },
      queries: { retry: false },
    },
  });

  const view = render(
    <QueryClientProvider client={queryClient}>
      <SpreadsheetImportPanel />
    </QueryClientProvider>
  );

  return {
    cleanup: () => {
      queryClient.clear();
      view.unmount();
    },
  };
}

function readBlobText(blob: Blob) {
  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader();

    reader.onerror = () => reject(reader.error);
    reader.onload = () => resolve(String(reader.result));
    reader.readAsText(blob);
  });
}
