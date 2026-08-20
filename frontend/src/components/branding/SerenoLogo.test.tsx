import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { SerenoLogo } from "./SerenoLogo";

describe("SerenoLogo", () => {
  it("porte toujours le nom accessible Sereno", () => {
    render(<SerenoLogo />);

    expect(screen.getByRole("img", { name: "Sereno" })).toBeInTheDocument();
  });

  it("utilise l’asset vectoriel partagé et respecte ses props", () => {
    const { container } = render(
      <SerenoLogo size={44} className="logo-test" />,
    );

    const logo = screen.getByRole("img", { name: "Sereno" });

    expect(logo).toHaveAttribute("src", "/sereno-mark.svg");
    expect(logo).toHaveAttribute("width", "44");
    expect(logo).toHaveAttribute("height", "44");
    expect(logo).toHaveClass("logo-test");
    expect(logo).toHaveAttribute("draggable", "false");
    expect(container.querySelector("svg")).not.toBeInTheDocument();
  });

  it("plusieurs instances partagent la même source", () => {
    const { container } = render(
      <>
        <SerenoLogo />
        <SerenoLogo />
      </>,
    );

    const logos = screen.getAllByRole("img", { name: "Sereno" });

    expect(logos).toHaveLength(2);
    expect(
      logos.every(
        (logo) => logo.getAttribute("src") === "/sereno-mark.svg",
      ),
    ).toBe(true);
    expect(container.querySelector("defs")).not.toBeInTheDocument();
  });
});