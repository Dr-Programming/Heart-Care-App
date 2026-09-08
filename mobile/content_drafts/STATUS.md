# Education content status

Nothing is held out of `assets/content/` anymore — this directory is now just
a historical note. `topics_en.json` and `topics_am.json` both carry all 7 spec
topics (`chd-basics`, `symptoms`, `heart-attack`, `diet`, `exercise`,
`medication-adherence`, `psychosocial`), matching structure and order, plus
`quiz_en.json`/`quiz_am.json` (12 questions each).

- **`diet`** — resolved 2026-09-03. Ethiopian-specific content (Ethiopia's
  Food-Based Dietary Guidelines + glycemic-index research). Blood Pressure and
  Cholesterol sections deliberately stayed general (WHO's global 5g/day salt
  figure, not Australia-specific — no localization needed).
- **`psychosocial`** — resolved 2026-09-03. Real content sourced from an AHA
  scientific statement and cardiac rehabilitation psychosocial-management
  literature.

**Still outstanding, not a content gap:** all Amharic content in this file is
AI-translated and needs a native-speaker review pass before release, same as
the rest of this slice's Amharic strings — flag it in the PR, don't let it
ship unreviewed.
