import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen, waitFor, within } from '@testing-library/react';
import { userEvent } from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { FlatFileImportPanel } from '@/components/FlatFileImportPanel.tsx';
import { server } from '@/test/mswUtils.ts';

describe('FlatFileImportPanel', () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
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
          filename: 'active-projects.csv',
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
      expect(screen.getByLabelText('Import file')).toHaveAttribute(
        'accept',
        '.csv,.xlsx'
      );
      await user.upload(
        screen.getByLabelText('Import file'),
        new File(['test'], 'active-projects.csv', {
          type: 'text/csv',
        })
      );
      await user.click(screen.getByRole('button', { name: 'Upload' }));

      expect(
        await screen.findByText('Imported 42 rows from active-projects.csv.')
      ).toBeInTheDocument();
      expect(postedDataset).toBe('active-projects');
    } finally {
      cleanup();
    }
  });

  it('requires files to be reselected before another upload', async () => {
    const user = userEvent.setup();
    let postCount = 0;

    server.use(
      http.get('/api/imports/recent', () => HttpResponse.json([])),
      http.post('/api/imports/:dataset', () => {
        postCount += 1;

        return HttpResponse.json({
          dataset: 'all-projects',
          filename: 'all-projects.csv',
          importedAt: '2026-06-09T18:30:00Z',
          importLogId: postCount,
          rowsImported: postCount,
          succeeded: true,
        });
      })
    );

    const { cleanup } = renderPanel();

    try {
      await user.upload(
        screen.getByLabelText('Import file'),
        new File(['test'], 'all-projects.csv', {
          type: 'text/csv',
        })
      );

      await user.click(screen.getByRole('button', { name: 'Upload' }));
      expect(
        await screen.findByText('Imported 1 rows from all-projects.csv.')
      ).toBeInTheDocument();
      expect(screen.getByLabelText('Import file')).toHaveValue('');
      expect(screen.getByRole('button', { name: 'Upload' })).toBeDisabled();
      expect(
        screen.queryByText(/Select all-projects\.csv again/)
      ).not.toBeInTheDocument();

      await user.upload(
        screen.getByLabelText('Import file'),
        new File(['test again'], 'all-projects.csv', {
          type: 'text/csv',
        })
      );
      await user.click(screen.getByRole('button', { name: 'Upload' }));
      expect(
        await screen.findByText('Imported 2 rows from all-projects.csv.')
      ).toBeInTheDocument();

      expect(postCount).toBe(2);
      expect(
        screen.queryByText('The import could not be completed.')
      ).not.toBeInTheDocument();
    } finally {
      cleanup();
    }
  });

  it('clears the selected file after success even when refreshed import data is still loading', async () => {
    const user = userEvent.setup();

    server.use(
      http.get('/api/imports/recent', () => new Promise(() => {})),
      http.post('/api/imports/:dataset', () =>
        HttpResponse.json({
          dataset: 'all-projects',
          filename: 'all-projects.csv',
          importedAt: '2026-06-09T18:30:00Z',
          importLogId: 48,
          rowsImported: 1,
          succeeded: true,
        })
      )
    );

    const { cleanup } = renderPanel();

    try {
      await user.upload(
        screen.getByLabelText('Import file'),
        new File(['test'], 'all-projects.csv', {
          type: 'text/csv',
        })
      );
      await user.click(screen.getByRole('button', { name: 'Upload' }));

      expect(
        await screen.findByText('Imported 1 rows from all-projects.csv.')
      ).toBeInTheDocument();
      expect(screen.getByLabelText('Import file')).toHaveValue('');
      expect(screen.getByRole('button', { name: 'Upload' })).toBeDisabled();
    } finally {
      cleanup();
    }
  });

  it('uploads a reselected file when the corrected file has the same name', async () => {
    const user = userEvent.setup();
    let uploadedText = '';

    vi.spyOn(globalThis, 'fetch').mockImplementation(async (input, init) => {
      const url = getRequestUrl(input);

      if (url === '/api/imports/recent') {
        return Response.json([]);
      }

      if (url === '/api/imports/all-projects') {
        const formData = init?.body as FormData;
        const postedFile = formData.get('file');
        uploadedText =
          postedFile && typeof postedFile === 'object' && isBlobLike(postedFile)
            ? await readBlobText(postedFile)
            : String(postedFile);

        return Response.json({
          dataset: 'all-projects',
          filename: 'all-projects.csv',
          importedAt: '2026-06-09T18:30:00Z',
          importLogId: 49,
          rowsImported: 1,
          succeeded: true,
        });
      }

      return new Response(null, { status: 404 });
    });

    const { cleanup } = renderPanel();

    try {
      await user.upload(
        screen.getByLabelText('Import file'),
        new File(['old contents'], 'all-projects.csv', {
          type: 'text/csv',
        })
      );
      await user.upload(
        screen.getByLabelText('Import file'),
        new File(['corrected contents'], 'all-projects.csv', {
          type: 'text/csv',
        })
      );
      await user.click(screen.getByRole('button', { name: 'Upload' }));

      expect(
        await screen.findByText('Imported 1 rows from all-projects.csv.')
      ).toBeInTheDocument();
      expect(uploadedText).toBe('corrected contents');
    } finally {
      cleanup();
    }
  });

  it('shows a generic failure when an upload is rejected before validation', async () => {
    const user = userEvent.setup();

    vi.spyOn(globalThis, 'fetch').mockImplementation(async (input) => {
      const url = getRequestUrl(input);

      if (url === '/api/imports/recent') {
        return Response.json([]);
      }

      if (url === '/api/imports/all-projects') {
        return new Response('Bad Request', { status: 400 });
      }

      return new Response(null, { status: 404 });
    });

    const { cleanup } = renderPanel();

    try {
      await user.upload(
        screen.getByLabelText('Import file'),
        new File(['test'], 'all-projects.xlsx', {
          type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        })
      );
      await user.click(screen.getByRole('button', { name: 'Upload' }));

      expect(
        await screen.findByText('The import could not be completed.')
      ).toBeInTheDocument();
      expect(
        screen.queryByText(/all-projects\.xlsx could not be uploaded/)
      ).not.toBeInTheDocument();
      expect(screen.getByLabelText('Import file')).toHaveValue('');
      expect(screen.getByRole('button', { name: 'Upload' })).toBeDisabled();
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
        screen.getByLabelText('Import file'),
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

  it('pages validation failures with direct navigation and selectable page size', async () => {
    const user = userEvent.setup();
    const rows = Array.from({ length: 31 }, (_, index) => {
      const rowNum = index + 1;

      return {
        cellErrors: [
          {
            code: 'required',
            message: `OrganizationName is required for row ${rowNum}.`,
            rawValue: '',
            sourceHeader: 'Organization Name',
            targetColumn: 'OrganizationName',
          },
        ],
        errors: [],
        rowNum,
        values: {
          AccessionNumber: `A-${rowNum}`,
          OrganizationName: '',
        },
      };
    });

    server.use(
      http.get('/api/imports/recent', () => HttpResponse.json([])),
      http.post('/api/imports/:dataset', () =>
        HttpResponse.json(
          {
            attemptedRows: rows.length,
            dataset: 'all-projects',
            fileErrors: [],
            filename: 'all-projects.xlsx',
            importLogId: 46,
            rows,
            succeeded: false,
          },
          { status: 400 }
        )
      )
    );

    const { cleanup } = renderPanel();

    try {
      await user.upload(
        screen.getByLabelText('Import file'),
        new File(['test'], 'all-projects.xlsx', {
          type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        })
      );
      await user.click(screen.getByRole('button', { name: 'Upload' }));

      expect(
        await screen.findByText(
          'Import failed validation for 31 of 31 attempted rows.'
        )
      ).toBeInTheDocument();
      expect(screen.getByLabelText('Page')).toHaveValue(1);
      expect(screen.getByText('of 4')).toBeInTheDocument();
      expect(screen.getByLabelText('Rows per page')).toHaveValue('10');

      await user.click(screen.getByRole('button', { name: 'Last' }));
      expect(screen.getByLabelText('Page')).toHaveValue(4);
      expect(screen.getByText('31')).toBeInTheDocument();

      await user.click(screen.getByRole('button', { name: 'First' }));
      expect(screen.getByLabelText('Page')).toHaveValue(1);
      expect(screen.getByText('1')).toBeInTheDocument();

      await user.clear(screen.getByLabelText('Page'));
      await user.type(screen.getByLabelText('Page'), '3');
      expect(screen.getByLabelText('Page')).toHaveValue(3);
      expect(screen.getByText('21')).toBeInTheDocument();

      await user.selectOptions(screen.getByLabelText('Rows per page'), '25');
      expect(screen.getByLabelText('Rows per page')).toHaveValue('25');
      expect(screen.getByText('of 2')).toBeInTheDocument();
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
        screen.getByLabelText('Import file'),
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
      <FlatFileImportPanel />
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

function getRequestUrl(input: RequestInfo | URL) {
  if (typeof input === 'string') {
    return input;
  }

  return 'url' in input ? input.url : input.toString();
}

function isBlobLike(value: object): value is Blob {
  return 'size' in value && 'slice' in value && 'type' in value;
}
