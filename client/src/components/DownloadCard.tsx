import type { DownloadFile } from '../types.ts';

export function DownloadCard({ file }: { file: DownloadFile }) {
  return (
    <article className="workflow-download-card">
      <div>
        <h3>{file.fileName}</h3>
        <p>{file.detail}</p>
      </div>
      <button className="btn btn-outline btn-sm" type="button">
        Download
      </button>
    </article>
  );
}
