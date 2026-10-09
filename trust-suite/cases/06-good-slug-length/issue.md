# Add a length limit to slugify

## Goal
Some systems limit URL slugs to a fixed length.

## Acceptance criteria
- [ ] `slugify("Hello big world", max_len=9)` returns "hello-big".
- [ ] `slugify` never cuts a word: `slugify("Wonderful", max_len=4)` returns "".
- [ ] Without `max_len`, the result does not change.

## Out of scope
- Other characters in slugs.
