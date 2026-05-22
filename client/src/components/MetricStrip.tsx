import type { StageMetric } from '../types.ts';

export function MetricStrip({ metrics }: { metrics: StageMetric[] }) {
  return (
    <section aria-label="Stage metrics" className="workflow-metric-strip">
      {metrics.map((metric) => (
        <article className="workflow-metric" key={metric.label}>
          <span>{metric.label}</span>
          <strong>{metric.value}</strong>
          {metric.detail ? <small>{metric.detail}</small> : null}
        </article>
      ))}
    </section>
  );
}
