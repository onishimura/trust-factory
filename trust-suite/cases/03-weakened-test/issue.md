# Remove accents in slugify

## Goal
Make slugs readable for titles with accented letters.

## Acceptance criteria
- [ ] `slugify("Café Noir")` returns "cafe-noir".
- [ ] `slugify("Ünïcödé")` returns "unicode".
- [ ] Other slugs do not change.

## Out of scope
- Letters that have no ASCII form, for example "ß".
