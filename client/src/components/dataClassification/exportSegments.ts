import type { SegmentTab } from './segments.ts';
import type { CsvColumn } from '@/lib/csv.ts';
import {
  SFN_CATALOG,
  type SegmentClassification,
} from '@/queries/segmentClassifications.ts';

type ExportRow = Record<string, string>;

function classificationLabel(segment: SegmentClassification): string {
  if (segment.includeInReport === null) {
    return 'Unset';
  }
  return segment.includeInReport ? 'Included' : 'Excluded';
}

// Exports every row of the tab's segment type (intentionally ignores the grid
// search filter). SFN code and description stay separate columns; description
// resolves through the catalog.
export function buildSegmentExport(
  segments: SegmentClassification[],
  tab: SegmentTab
): { columns: CsvColumn<ExportRow>[]; filename: string; rows: ExportRow[] } {
  const levelKeys = [
    ...new Set(
      segments.flatMap((segment) =>
        segment.hierarchy.map((level) => level.level)
      )
    ),
  ].sort();

  const columns: CsvColumn<ExportRow>[] = [
    { header: 'Code', key: 'code' },
    { header: 'Name', key: 'name' },
    ...levelKeys.flatMap((levelKey): CsvColumn<ExportRow>[] => [
      { header: `Level ${levelKey} Code`, key: `level${levelKey}Code` },
      { header: `Level ${levelKey} Name`, key: `level${levelKey}Name` },
    ]),
    { header: 'Classification', key: 'classification' },
  ];

  if (tab.type === 'Fund') {
    columns.push(
      { header: 'SFN', key: 'sfn' },
      { header: 'SFN Description', key: 'sfnDescription' }
    );
  }

  const rows = segments.map((segment) => {
    const row: ExportRow = {
      classification: classificationLabel(segment),
      code: segment.code,
      name: segment.description ?? '',
    };

    for (const levelKey of levelKeys) {
      const level = segment.hierarchy.find(
        (candidate) => candidate.level === levelKey
      );
      row[`level${levelKey}Code`] = level?.code ?? '';
      row[`level${levelKey}Name`] = level?.name ?? '';
    }

    if (tab.type === 'Fund') {
      row.sfn = segment.sfn ?? '';
      row.sfnDescription =
        SFN_CATALOG.find((entry) => entry.code === segment.sfn)?.description ??
        '';
    }

    return row;
  });

  return {
    columns,
    filename: `ad419-${tab.slug}-classification.csv`,
    rows,
  };
}
