import { useEffect, useId, useRef, type ReactNode } from 'react';

export function ConfirmationDialog({
  cancelLabel = 'Cancel',
  children,
  confirmClassName = 'btn-primary',
  confirmLabel,
  onCancel,
  onConfirm,
  open,
  title,
}: {
  cancelLabel?: string;
  children: ReactNode;
  confirmClassName?: string;
  confirmLabel: string;
  onCancel: () => void;
  onConfirm: () => void;
  open: boolean;
  title: string;
}) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const titleId = useId();

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) {
      return;
    }

    if (open && !dialog.open) {
      if (typeof dialog.showModal === 'function') {
        dialog.showModal();
      } else {
        dialog.setAttribute('open', '');
      }
      return;
    }

    if (!open && dialog.open) {
      if (typeof dialog.close === 'function') {
        dialog.close();
      } else {
        dialog.removeAttribute('open');
      }
    }
  }, [open]);

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) {
      return;
    }

    const handleCancel = (event: Event) => {
      event.preventDefault();
      onCancel();
    };

    dialog.addEventListener('cancel', handleCancel);
    return () => dialog.removeEventListener('cancel', handleCancel);
  }, [onCancel]);

  return (
    <dialog aria-labelledby={titleId} className="modal" ref={dialogRef}>
      <div className="modal-box max-w-lg">
        <h2 className="text-lg font-bold text-base-content" id={titleId}>
          {title}
        </h2>
        <div className="mt-3 text-sm text-base-content/70">{children}</div>
        <div className="modal-action">
          <button className="btn btn-ghost" onClick={onCancel} type="button">
            {cancelLabel}
          </button>
          <button
            className={`btn ${confirmClassName}`}
            onClick={onConfirm}
            type="button"
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </dialog>
  );
}
