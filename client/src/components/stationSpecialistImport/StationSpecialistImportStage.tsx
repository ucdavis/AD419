import {
  FlatFileImportPanel,
  type ImportDatasetId,
} from '@/components/FlatFileImportPanel.tsx';
import { SectionPanel } from '@/components/SectionPanel.tsx';

const panels: Array<{
  dataset: ImportDatasetId;
  description: string;
  title: string;
}> = [
  {
    dataset: 'field-station-expenses',
    description:
      'Upload the Field Station expense workbook supplied for this reporting cycle.',
    title: 'Field Station Expenses',
  },
  {
    dataset: 'ce-specialists',
    description:
      'Upload the CE Specialist workbook supplied for this reporting cycle.',
    title: 'CE Specialists',
  },
];

export function StationSpecialistImportStage() {
  return (
    <>
      <div className="alert">
        <span>
          These files can be uploaded at any point in the cycle and do not block
          the other workflow stages.
        </span>
      </div>

      {panels.map((panel) => (
        <SectionPanel key={panel.dataset} title={panel.title}>
          <div className="space-y-4 p-4">
            <p className="text-sm text-base-content/70">{panel.description}</p>
            <FlatFileImportPanel dataset={panel.dataset} />
          </div>
        </SectionPanel>
      ))}
    </>
  );
}
