type SerenoLogoProps = {
  size?: number;
  className?: string;
};

/**
 * Marque Sereno officielle de l’interface.
 *
 * Le nom accessible reste présent lorsque la sidebar est repliée.
 */
export function SerenoLogo({ size = 38, className }: SerenoLogoProps) {
  return (
    <img
      src="/sereno-mark.svg"
      width={size}
      height={size}
      alt="Sereno"
      className={className}
      draggable={false}
    />
  );
}