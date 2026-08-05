import { act, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { useStickyCompact } from "./useStickyCompact";

type IntersectionCallback = (
  entries: Array<{ isIntersecting: boolean }>,
) => void;

let intersectionCallback: IntersectionCallback | null = null;

class MockResizeObserver {
  observe = vi.fn();
  unobserve = vi.fn();
  disconnect = vi.fn();
}

class MockIntersectionObserver {
  constructor(callback: IntersectionCallback) {
    intersectionCallback = callback;
  }
  observe = vi.fn();
  unobserve = vi.fn();
  disconnect = vi.fn();
}

// Composant sonde : la mécanique dépend de refs réellement attachées à des
// éléments du DOM (sentinelle + section) — un renderHook seul ne les
// attacherait jamais, donc on rend un vrai petit arbre pour l'exercer.
function Probe() {
  const { sentinelRef, sectionRef, isEligibleForSticky, isCompact } =
    useStickyCompact();

  return (
    <>
      <div ref={sentinelRef} data-testid="sentinel" />
      <section ref={sectionRef}>
        <span data-testid="eligible">{String(isEligibleForSticky)}</span>
        <span data-testid="compact">{String(isCompact)}</span>
      </section>
    </>
  );
}

function setDocumentTallerThan(viewport: number, scrollHeight: number) {
  Object.defineProperty(window, "innerHeight", {
    value: viewport,
    configurable: true,
  });
  Object.defineProperty(document.documentElement, "scrollHeight", {
    value: scrollHeight,
    configurable: true,
  });
}

describe("useStickyCompact", () => {
  const originalResizeObserver = globalThis.ResizeObserver;
  const originalIntersectionObserver = globalThis.IntersectionObserver;

  beforeEach(() => {
    intersectionCallback = null;
    globalThis.ResizeObserver =
      MockResizeObserver as unknown as typeof ResizeObserver;
    globalThis.IntersectionObserver =
      MockIntersectionObserver as unknown as typeof IntersectionObserver;
  });

  afterEach(() => {
    globalThis.ResizeObserver = originalResizeObserver;
    globalThis.IntersectionObserver = originalIntersectionObserver;
  });

  it("devient éligible au sticky sur une page suffisamment longue (> 2x le viewport)", () => {
    setDocumentTallerThan(800, 2000);

    render(<Probe />);

    expect(screen.getByTestId("eligible").textContent).toBe("true");
  });

  it("cas négatif — page courte : jamais compact, même si la sentinelle sort du viewport", () => {
    // scrollHeight (1000) <= 2 * innerHeight (800) -> inéligible par construction.
    setDocumentTallerThan(800, 1000);

    render(<Probe />);

    expect(screen.getByTestId("eligible").textContent).toBe("false");

    // Simule la sentinelle qui sort du viewport (déclencherait isStuck=true
    // sur une page éligible) : le garde-fou doit l'ignorer.
    act(() => {
      intersectionCallback?.([{ isIntersecting: false }]);
    });

    expect(screen.getByTestId("compact").textContent).toBe("false");
  });
});
