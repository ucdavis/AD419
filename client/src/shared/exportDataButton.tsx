import { HttpError } from '@/lib/api.ts';
import {
  type CsvColumn,
  downloadBlob,
  downloadExcelCsv,
  toExcelCsv,
} from '@/lib/csv.ts';
import { useState } from 'react';

interface ExportDataButtonProps<T> {
  className?: string;
  columns: CsvColumn<T>[];
  data: T[];
  filename: string;
  label?: string;
}

export function ExportDataButton<T>({
  className = '',
  columns,
  data,
  filename,
  label = 'Export',
}: ExportDataButtonProps<T>) {
  const handleExport = () => {
    const csv = toExcelCsv(data, columns);
    downloadExcelCsv(csv, filename);
  };

  return (
    <button
      className={`btn btn-sm ${className}`.trim()}
      onClick={handleExport}
      type="button"
    >
      <svg
        aria-hidden="true"
        className="h-4 w-4"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path
          d="M12 16V4m0 12 4-4m-4 4-4-4M5 20h14"
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth={2}
        />
      </svg>
      {label}
    </button>
  );
}

interface ExportEndpointButtonProps {
  className?: string;
  disabled?: boolean;
  filename?: string;
  label?: string;
  onError?: (error: unknown) => void;
  onSuccess?: () => void;
  pendingLabel?: string;
  url: string;
}

function filenameFromContentDisposition(header: string | null) {
  if (!header) {
    return null;
  }

  const encodedFilename = /filename\*=utf-8''([^;]+)/i.exec(header);
  if (encodedFilename?.[1]) {
    return decodeURIComponent(encodedFilename[1].replaceAll('"', ''));
  }

  const quotedFilename = /filename="([^"]+)"/i.exec(header);
  if (quotedFilename?.[1]) {
    return quotedFilename[1];
  }

  const filename = /filename=([^;]+)/i.exec(header);
  return filename?.[1]?.trim() ?? null;
}

async function readErrorBody(response: Response) {
  const text = await response.text();
  if (!text) {
    return undefined;
  }

  if (response.headers.get('content-type')?.includes('application/json')) {
    try {
      return JSON.parse(text) as unknown;
    } catch {
      return text;
    }
  }

  return text;
}

export function ExportEndpointButton({
  className = '',
  disabled = false,
  filename = 'export.csv',
  label = 'Export',
  onError,
  onSuccess,
  pendingLabel = 'Exporting...',
  url,
}: ExportEndpointButtonProps) {
  const [isPending, setIsPending] = useState(false);

  const handleExport = async () => {
    setIsPending(true);

    try {
      const response = await fetch(url, {
        credentials: 'same-origin',
        headers: { Accept: 'text/csv' },
      });

      if (!response.ok) {
        throw new HttpError(
          response.status,
          url,
          await readErrorBody(response)
        );
      }

      const blob = await response.blob();
      downloadBlob(
        blob,
        filenameFromContentDisposition(
          response.headers.get('content-disposition')
        ) ?? filename
      );
      onSuccess?.();
    } catch (error) {
      onError?.(error);
    } finally {
      setIsPending(false);
    }
  };

  return (
    <button
      className={`btn btn-sm ${className}`.trim()}
      disabled={disabled || isPending}
      onClick={() => void handleExport()}
      type="button"
    >
      <svg
        aria-hidden="true"
        className="h-4 w-4"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path
          d="M12 16V4m0 12 4-4m-4 4-4-4M5 20h14"
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth={2}
        />
      </svg>
      {isPending ? pendingLabel : label}
    </button>
  );
}
