import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { SerenoLogo } from "./SerenoLogo";

describe("SerenoLogo", () => {
  it("se rend avec un rôle accessible", () => {
    render(<SerenoLogo />);

    expect(screen.getByRole("img", { name: "Sereno" })).toBeInTheDocument();
  });

  it("deux instances sur la même page n'ont jamais le même id de dégradé (useId)", () => {
    render(
      <>
        <SerenoLogo />
        <SerenoLogo />
      </>,
    );

    const [first, second] = screen.getAllByRole("img", { name: "Sereno" });
    const gradientIdOf = (svg: Element) => svg.querySelector("linearGradient")?.id;

    expect(gradientIdOf(first)).toBeTruthy();
    expect(gradientIdOf(second)).toBeTruthy();
    expect(gradientIdOf(first)).not.toBe(gradientIdOf(second));
  });
});
