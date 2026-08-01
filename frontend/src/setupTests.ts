// Entrée dédiée Vitest : importe `expect` depuis 'vitest' en interne et
// l'étend directement, sans dépendre d'un `expect` global (config sans
// `test.globals: true`, cf. vite.config.ts).
import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/react';
import { afterEach } from 'vitest';

// Nettoyage explicite après chaque test : sans `test.globals: true`,
// @testing-library/react ne détecte pas de global `afterEach` et n'enregistre
// pas son cleanup auto.
afterEach(() => {
  cleanup();
});
