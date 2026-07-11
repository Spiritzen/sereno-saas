import {
  useEffect,
  useRef,
  type KeyboardEvent,
  type MouseEvent,
  type ReactNode,
  type RefObject,
} from "react";
import { createPortal } from "react-dom";

type ModalShellProps = {
  open: boolean;
  onClose: () => void;
  children: ReactNode;
  labelledBy: string;
  describedBy?: string;
  isDismissDisabled?: boolean;
  initialFocusRef?: RefObject<HTMLElement | null>;
  className?: string;
  surfaceClassName?: string;
};

const FOCUSABLE_SELECTOR = [
  "button:not([disabled])",
  "[href]",
  "input:not([disabled])",
  "select:not([disabled])",
  "textarea:not([disabled])",
  '[tabindex]:not([tabindex="-1"])',
].join(",");

function isVisible(element: HTMLElement) {
  return (
    element.offsetWidth > 0 ||
    element.offsetHeight > 0 ||
    element === document.activeElement
  );
}

function getFocusableElements(container: HTMLElement) {
  const elements = Array.from(
    container.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR),
  );

  return elements.filter(
    (element) =>
      !element.hasAttribute("aria-hidden") &&
      !element.closest('[aria-hidden="true"]') &&
      isVisible(element),
  );
}

export function ModalShell({
  open,
  onClose,
  children,
  labelledBy,
  describedBy,
  isDismissDisabled = false,
  initialFocusRef,
  className,
  surfaceClassName,
}: ModalShellProps) {
  const surfaceRef = useRef<HTMLDivElement | null>(null);
  const previouslyFocusedRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (!open) {
      return;
    }

    previouslyFocusedRef.current =
      document.activeElement instanceof HTMLElement
        ? document.activeElement
        : null;

    const timeoutId = window.setTimeout(() => {
      const target =
        initialFocusRef?.current ??
        (surfaceRef.current ? getFocusableElements(surfaceRef.current)[0] : null) ??
        surfaceRef.current;

      target?.focus();
    }, 0);

    return () => {
      window.clearTimeout(timeoutId);

      const previouslyFocused = previouslyFocusedRef.current;

      if (previouslyFocused && document.contains(previouslyFocused)) {
        previouslyFocused.focus();
      }
    };
  }, [open, initialFocusRef]);

  useEffect(() => {
    if (!open) {
      return;
    }

    function handleKeyDown(event: globalThis.KeyboardEvent) {
      if (event.key !== "Escape" || isDismissDisabled) {
        return;
      }

      onClose();
    }

    document.addEventListener("keydown", handleKeyDown);

    return () => {
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [open, isDismissDisabled, onClose]);

  useEffect(() => {
    if (!open) {
      return;
    }

    const body = document.body;
    const previousOverflow = body.style.overflow;
    const previousPaddingRight = body.style.paddingRight;
    const scrollbarWidth = window.innerWidth - document.documentElement.clientWidth;

    body.style.overflow = "hidden";

    if (scrollbarWidth > 0) {
      const currentPaddingRight = Number.parseFloat(previousPaddingRight || "0") || 0;

      body.style.paddingRight = `${currentPaddingRight + scrollbarWidth}px`;
    }

    return () => {
      body.style.overflow = previousOverflow;
      body.style.paddingRight = previousPaddingRight;
    };
  }, [open]);

  if (!open || typeof document === "undefined") {
    return null;
  }

  function handleBackdropMouseDown(event: MouseEvent<HTMLDivElement>) {
    if (event.target !== event.currentTarget || isDismissDisabled) {
      return;
    }

    onClose();
  }

  function handleSurfaceKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    if (event.key !== "Tab" || !surfaceRef.current) {
      return;
    }

    const focusableElements = getFocusableElements(surfaceRef.current);
    const first = focusableElements[0];
    const last = focusableElements[focusableElements.length - 1];

    if (!first || !last) {
      event.preventDefault();
      return;
    }

    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
      return;
    }

    if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  }

  return createPortal(
    <div
      className={`modal-shell${className ? ` ${className}` : ""}`}
      role="presentation"
      onMouseDown={handleBackdropMouseDown}
    >
      <div
        ref={surfaceRef}
        className={`modal-shell__surface${surfaceClassName ? ` ${surfaceClassName}` : ""}`}
        role="dialog"
        aria-modal="true"
        aria-labelledby={labelledBy}
        aria-describedby={describedBy}
        tabIndex={-1}
        onKeyDown={handleSurfaceKeyDown}
      >
        {children}
      </div>
    </div>,
    document.body,
  );
}
